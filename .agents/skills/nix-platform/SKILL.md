---
name: nix-platform
description: >
  Nix practices for loic-roux-404/k3s-paas split between nix-darwin (macOS dev workstation)
  and NixOS (server/VM images). Covers flake structure, nixos-generators qcow2 builds,
  srvos base modules, paas.* option namespace, home-manager integration, sops-nix,
  nix-darwin libvirt/dnsmasq/pebble launchd daemons, linux-builder cross-compilation,
  devShell conventions, and nix-darwin bootstrap.
  Use when modifying NixOS configs, adding packages to the devShell, changing the paas.*
  option schema, building new qcow2 images, debugging nix-darwin daemons, or reasoning
  about cross-compilation for aarch64-linux on Apple Silicon.
metadata:
  version: "1.0.0"
  domain: nix
  triggers: >
    nix, nixos, nix-darwin, flake.nix, nixosConfigurations, darwinConfigurations,
    nixos-generators, srvos, sops-nix, home-manager, paas, mkDarwinSystem,
    launchd, linux-builder, nix build, nix develop, nixos-rebuild, qcow2,
    paas-secrets, nixos-options, nixpkgs-srvos
  role: platform-engineer
  scope: implementation
  output-format: code
---

# Nix Platform Specialist

## Flake Structure

```
inputs:
  nixpkgs          → 25.11 stable (used for overlays)
  srvos            → numtide server hardening (pins its own nixpkgs)
  nixpkgs-srvos    → follows srvos/nixpkgs (used for most packages)
  darwin           → nix-darwin 25.11
  home-manager     → follows srvos/nixpkgs
  nixos-generators → follows srvos/nixpkgs
  sops-nix         → NixOS sops module
  flake-utils      → eachDefaultSystem helper
```

**Package source priority**: prefer `nixpkgs-srvos` (srvos-pinned) over `nixpkgs` (stable). Use `pkgs.pkgs-stable` overlay only when you need a specific stable version not in srvos.

---

## nix-darwin (macOS Developer Workstation)

### Purpose

The nix-darwin config at `nixos-darwin/configuration.nix` turns the macOS host into:
- A **Linux cross-compilation host** via `nix.linux-builder` (ephemeral aarch64-linux VM)
- A **libvirt hypervisor** running libvirtd + virtlogd as launchd daemons
- A **local DNS resolver** via dnsmasq for `*.kube.test` pointing to the VM IP
- A **local ACME CA** via Pebble for TLS testing
- A **local object store** via MinIO

### Bootstrap Sequence

```bash
# 1. Install Nix (Determinate Systems installer — required)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Add nix-daemon to fish config (or bash equivalent)
echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish' >> ~/.config/fish/config.fish

# 3. Bootstrap nix-darwin (runs darwin-rebuild switch)
make bootstrap                  # aarch64-darwin (Apple Silicon default)
make bootstrap-contabo          # x86_64 cross-compile variant
```

### darwinConfigurations

| Name | Purpose |
|---|---|
| `builder` (default) | Standard Apple Silicon dev workstation |
| `builder-x86` | Adds x86_64 cross-compilation support via `configuration-x86.nix` |

### Key nix-darwin Options

```nix
# nix.linux-builder — provides aarch64-linux build capability on Apple Silicon
nix.linux-builder = {
  enable   = true;
  maxJobs  = 2;
  package  = lib.mkDefault pkgs.darwin.linux-builder;
  ephemeral = lib.mkDefault true;  # VM is rebuilt on each activation
};

# extra-platforms — enables building aarch64-linux packages natively
nix.settings.extra-platforms = [ "aarch64-linux" ];
```

### Adding a New launchd Daemon

Follow the existing pattern (libvirt, pebble, minio):
```nix
launchd.daemons.my-service = {
  serviceConfig = {
    KeepAlive        = true;
    RunAtLoad        = true;
    ProgramArguments = [ "${pkgs.my-tool}/bin/my-tool" "--flag" ];
    WorkingDirectory = "/var/lib/my-service";
    StandardOutPath  = "/var/log/my-service.log";
    StandardErrorPath = "/var/log/my-service-error.log";
  };
};
```

### libvirt on macOS — Critical Notes

libvirtd is started by launchd in **direct mode** (`mode = "direct"` in libvirtd.conf) with `unix_sock_group = "staff"`.
The QEMU security driver is disabled (`security_driver = "none"`).
`dynamic_ownership = 0` means QEMU does not chown disk images — volumes must be pre-owned by the correct user.

When libvirtd is not running or its socket is missing, run the darwin uninstaller and re-bootstrap:
```bash
./result/sw/bin/darwin-uninstaller
make bootstrap
```

### DNS Flush (macOS)

After nix-darwin activation changes dnsmasq config:
```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

### Shared paas.* Options in Darwin Context

`nixos-options/default.nix` is included as `darwinModules.config`.
`paas.dns.name` (default `kube.test`) and `paas.kube.addr` (default `192.168.2.2`) drive dnsmasq configuration.
`paas.certs` defaults to the Pebble cert path inside `nixos-darwin/pebble/` — this default is correct for Darwin, wrong for NixOS.

---

## Note: consuming private secrets repo as flake input

- When importing a private secrets repo into a flake, prefer `flake = false` in the input and pin using `nix flake lock --update-input secrets`.
- Use devShell `shellHook` to create a symlink from `./secrets` → pinned `/nix/store/...-source`. Advantages:
  - preserves existing `find_in_parent_folders("secrets/<env>.yaml")` usage in Terragrunt
  - avoids referencing plain `/nix/store` paths inside Nix eval (pure-eval error)
- Caveats:
  - `/nix/store` is world-readable on multi-user systems; secrets remain ciphertext but operator must avoid pushing closures to public caches.
  - darwin-rebuild with `sudo` may lose `SSH_AUTH_SOCK`; fetch as user first or prefetch the input.

The scripts live beside their derivation in `nixpkgs/paas-secrets/` (`default.nix`, `init-sops.sh`, `link-secrets.sh`) following the nixpkgs single-folder package convention:

```nix
paasSecretsPkg = pkgs.callPackage ./nixpkgs/paas-secrets { secrets = inputs.secrets; };
```

Example `shellHook` snippet (devShell):

```bash
# init sops env (exports SOPS_AGE_KEY / SOPS_AGE_RECIPIENTS)
source ${paasEnvPkg}/bin/init-sops
# symlink pinned secrets
${paasEnvPkg}/bin/link-secrets
```
## NixOS (Server / VM Images)

### Purpose

NixOS configs produce **bootable qcow2 disk images** via nixos-generators. These images are imported into libvirt (local) or uploaded to Contabo (cloud). The image has RKE2 baked in — there is no post-boot k8s installer.

### Available NixOS Configurations

| Name | Target | Modules |
|---|---|---|
| `initial` | Local libvirt (aarch64/x86_64) | default (srvos + os + config + qcow) |
| `deploy` | Local libvirt after nixos-rebuild | default + deploy.nix |
| `initial-contabo` | Contabo VPS (x86_64) | default + contabo.nix |
| `deploy-contabo` | Contabo after activation | default + deploy.nix + contabo.nix + master-0.nix |
| `container` | Docker testing | default + docker generator |

### Building a qcow2 Image

```bash
# aarch64-linux image (default for Apple Silicon dev)
nix build .#nixosConfigurations.initial.config.system.build.qcow

# x86_64-linux image for Contabo
nix build .#nixosConfigurations.initial-contabo.config.system.build.qcow

# Result symlinked to ./result/nixos.qcow2
# This path is the input to terragrunt/cloud/local/env.hcl
```

On Apple Silicon, building x86_64-linux requires the linux-builder to be active (`make bootstrap` first).

### Module Composition

NixOS modules are composed in `nixosAllModules` in `flake.nix`:
```nix
nixosAllModules = rec {
  default  = attrValues self.nixosModules;           # base
  contabo  = default ++ [ ./nixos/contabo.nix ];     # adds contabo-specific config
  deploy   = default ++ [ ./nixos/deploy.nix ];      # replaces initial with post-deploy config
  deployContabo = deploy ++ [ ./nixos/contabo.nix ];
};
```

To add a new variant:
1. Create `nixos/my-variant.nix`
2. Add to `nixosAllModules.myVariant = default ++ [ ./nixos/my-variant.nix ]`
3. Add a `nixosSystem` entry in the flake outputs

### paas.* Option Namespace

All cluster parameters flow through `nixos-options/default.nix`. **Do not hardcode values in configuration.nix.**

Common options to override per-environment:
```nix
# In nixos/contabo-master-0.nix or similar
paas.kube.addr       = "x.x.x.x";         # external IP
paas.dns.name        = "kube.example.com"; # production domain
paas.kube.token      = "...";              # from sops secrets
paas.user.key        = "ssh-ed25519 ...";  # operator SSH pubkey
```

### sops-nix Integration

The `nixosModules.sops` is `inputs.sops-nix.nixosModules.sops`.
Secrets are decrypted at activation using the VM's host key (placed via Terraform).
```nix
sops.defaultSopsFile = "/home/admin/secrets.yaml";
sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
sops.secrets.my-secret = {};
```

### srvos Base Modules

`srvos.nixosModules.common` and `srvos.nixosModules.server` are always included.
They provide: hardened SSH config, basic system packages, journal settings, systemd-networkd.
**Do not re-configure what srvos already sets** — use `lib.mkForce` only when you have a documented reason to override.

### Key NixOS Conventions

- Network interface: `enp0s9` hardcoded for QEMU — will fail on bare metal or Contabo. Contabo uses its own `contabo.nix` to override this
- `boot.loader.grub.device = lib.mkForce "/dev/sda"` — assumes single SATA disk
- `services.rke2.role = "server"` — single-node cluster only (no agent/worker node config exists)
- `home-manager.useGlobalPkgs = true; useUserPackages = true` — home-manager packages come from system nixpkgs
- Nix GC runs weekly, deletes derivations older than 30 days

### devShell

The `default` devShell provides the full platform toolchain:
```
terraform terragrunt sops ssh-to-age
kubernetes-helm cntb pebble
nil nixfmt nixos-rebuild
agent-lsp
```

The `shellHook` sources the `paas-secrets` derivation's `init-sops` script (`nixpkgs/paas-secrets/init-sops.sh`) to export `SOPS_AGE_KEY` / `SOPS_AGE_RECIPIENTS`, and runs `link-secrets` to symlink the pinned secrets input to `./secrets`. `DOCKER_HOST` is set in home-manager session variables, not the devShell.

**All platform operations must run inside `nix develop`.**

### Debugging Nix Builds

```bash
# Show all derivations in a config
nix derivation show -r '.#nixosConfigurations.initial.config.system.build.qcow'

# Filter by name
nix derivation show -r '.#nixosConfigurations.initial.config.system.build.qcow' \
  | jq -r '.[] | select(.name | contains("rke2"))'

# Interactive flake REPL
nix --extra-experimental-features repl-flake repl '.#'

# Verify and repair store
nix-store --verify --check-contents --repair

# Free unused derivations
nix-store --optimise
```

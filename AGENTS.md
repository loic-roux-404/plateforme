# AGENTS.md

This file provides guidance to AI coding agents working in this repository.

## Project Overview

This is a **Kubernetes PaaS (Platform as a Service)** infrastructure project that deploys a single-node RKE2 cluster on either:
- **Contabo VPS** (production)
- **Local libvirt VM** (development/testing)

The stack uses:
- **NixOS** for immutable infrastructure and VM image building
- **Terraform/Terragrunt** for infrastructure provisioning and Kubernetes app deployment
- **SOPS + age** for secrets management
- **RKE2** as the Kubernetes distribution
- **Dex + oauth2-proxy** for authentication
- **cert-manager** for TLS certificates
- **Longhorn** for persistent storage

Beyond the cluster itself, the **macOS host (nix-darwin)** used to set up and operate the PaaS is also configured in this repo:
- **home-manager** environment config (shells, git, editors, tools)
- **AI development stack** (Claude Code, VS Code chat) — all routed through the local LiteLLM gateway at `http://127.0.0.1:4000` (`nixos-darwin/litellm.nix`), which fronts OpenCode Zen and the Z.ai GLM coding plan behind OpenAI- and Anthropic-compatible endpoints

## Repository Structure

```
├── flake.nix                 # Nix flake: system configs, dev shells, packages
├── Makefile                  # Build orchestration (nix, terragrunt)
├── root.hcl                  # Terragrunt root config (state backend, inputs)
├── nixos/                    # NixOS system configurations
│   ├── configuration.nix     # Base NixOS config (kernel, network, RKE2)
│   ├── deploy.nix            # Deployment config (SOPS secrets, RKE2 templates)
│   ├── contabo.nix           # Contabo-specific settings
│   ├── contabo-master-0.nix  # Contabo master node settings
│   ├── qcow-compressed.nix   # QCOW2 image build config
│   └── docker.nix            # Docker container config
├── nixos-darwin/             # macOS (nix-darwin) control host configs
│   ├── configuration.nix     # Base darwin config (libvirt, dnsmasq, shells)
│   ├── configuration-x86.nix # x86_64 linux-builder config
│   ├── home-manager.nix      # Home-manager env config (shells, git, editors, tools)
│   ├── litellm.nix           # Local LiteLLM LLM gateway LaunchAgent (OpenCode Zen + Z.ai GLM)
│   ├── vscode-agent.nix      # VS Code chat language models (via local litellm proxy)
│   └── user-default.nix      # Default user settings (homebrew, shell)
├── nixos-options/            # Custom NixOS option definitions (paas.*)
├── nix-lib/                  # Nix library functions
│   └── mkDarwinSystem.nix    # Darwin system builder (takes secretsSopsFile param)
├── sops-defaults/            # Example encrypted sops file (placeholders) so
│   └── darwin.yaml           #   standalone k3s-paas darwin eval/build works
├── secrets -> ../secrets     # SYMLINK (gitignored): authoring repo org-404/secrets
│                              #   also hosts the private wrapper flake (bootstrap)
├── nixpkgs/plateforme-secrets/ # Dev-shell helpers: init-sops (age env),
│                              #   link-secrets (./secrets -> ../secrets)
├── terragrunt/               # Terragrunt environment configs
│   ├── cloud/                # Layer 1: VM provisioning
│   │   ├── contabo/          # Contabo VPS
│   │   └── local/            # Local libvirt
│   ├── network/              # Layer 2: DNS, Nix deploy, k3s config fetch
│   ├── paas/                 # Layer 3: Kubernetes platform (cert-manager, dex, longhorn)
│   └── apps/                 # Layer 4: Applications (n8n, supabase, appsmith, etc.)
├── tf-modules-cloud/         # Terraform modules for cloud providers
│   ├── contabo/              # Contabo VPS module
│   ├── gandi/                # Gandi DNS module
│   ├── libvirt/              # Local libvirt module
│   ├── k3s-get-config/       # Fetch kubeconfig from node
│   └── tailscale/            # Tailscale VPN module
├── tf-modules-k8s/           # Terraform modules for Kubernetes platform
│   ├── cert-manager/         # TLS certificate management
│   ├── cluster-infos/        # Cluster info discovery
│   ├── dex/                  # OIDC authentication
│   ├── internal-ca/          # Internal CA for local dev
│   ├── longhorn/             # Persistent storage
│   ├── metrics-server/       # Metrics server
│   ├── oauth2-proxy/         # OAuth2 proxy for app auth
│   └── pinniped/             # (empty, placeholder)
├── tf-modules-nix/           # Terraform modules for Nix deployment
│   └── deploy/               # NixOS deployment via SOPS + SSH
├── tf-modules-services/      # Terraform modules for applications
│   ├── appsmith/             # Appsmith low-code platform
│   ├── listmonk/             # Newsletter/mailing list
│   ├── minio/                # (empty, placeholder)
│   ├── mongodb/              # MongoDB database
│   ├── n8n/                  # n8n workflow automation
│   ├── postgres/             # PostgreSQL database
│   ├── smtp-relay/           # SMTP relay (postfix)
│   ├── supabase/             # Supabase backend-as-a-service
│   └── valkey/               # Valkey (Redis fork) cache
├── tf-modules-github/        # Terraform modules for GitHub
│   ├── repos-config/         # Repository secrets/variables
│   └── team/                 # Team management
├── tf-modules-monitoring/    # Monitoring stack (WIP)
│   ├── grafana/              # (empty)
│   ├── loki/                 # (empty)
│   └── victoria/             # (empty)
├── tf-root-*/                # Terraform root modules (composition layer)
│   ├── tf-root-network/      # Network layer composition
│   ├── tf-root-paas/         # PaaS layer composition
│   └── tf-root-apps/         # Apps layer composition
└── docs/                     # MkDocs documentation
```

## Build & Development Commands

### Mandatory Self-Review Before Every Command

Before ANY command:

1. **Check Execution History**
  - Review last 3 commands
  - Flag same command (tool + args) 2+ times
  - Flagged: propose alternative, no retry

2. **Run Self-Critique Checklist**
Answer explicitly:
  - "What did I try in last iteration?"
  - "How is this approach different?"
  - "What evidence this works when previous failed?"
  - "Making progress or just retrying?"

3. **Document in Scratchpad**
Write to `.agent/scratchpad.md`:
Iteration {N} - {timestamp}
  - Attempted: {command}
  - Result: {success/failure + error}
  - Similarity to previous: {unique/similar/identical}
  - Next approach: {must be different if similar/identical}

4. **Termination Conditions**

Stop + escalate if:
- Same command run 3 times without success
- 3 consecutive iterations >90% similar output
- No measurable progress in last 5 iterations
- Token count >80% of limit without completion

### Nix / NixOS

```bash
# Enter dev shell (includes terraform, terragrunt, sops, kubectl, helm)
nix develop

# Build NixOS qcow2 image for local libvirt
nix build .#nixosConfigurations.default --system aarch64-linux

# Build for x86_64 (Contabo)
nix build .#nixosConfigurations.default --system x86_64-linux

# Build and switch darwin configuration (delegates to ../secrets wrapper —
# real darwin.yaml + sibling working-tree override; see Secrets conventions)
make bootstrap          # aarch64-darwin mac os platform
make bootstrap-contabo  # x86_64-darwin (for Contabo builds)

# Build specific image formats
nix build .#nixosConfigurations.initial        # initial libvirt image
nix build .#nixosConfigurations.deploy         # deploy libvirt image
nix build .#nixosConfigurations.initial-contabo  # initial contabo image
nix build .#nixosConfigurations.deploy-contabo   # deploy contabo image
```

### Terragrunt (4-layer apply sequence)

```bash
# Layer 1: Cloud - provision VM
make terragrunt/cloud/local      # local libvirt
make terragrunt/cloud/contabo    # Contabo VPS

# Layer 2: Network - DNS, Nix deploy, fetch k3s config
make terragrunt/network/local
make terragrunt/network/contabo

# Layer 3: PaaS - Kubernetes platform (cert-manager, dex, longhorn)
make terragrunt/paas/local
make terragrunt/paas/contabo

# Layer 4: Apps - Applications (n8n, supabase, etc.)
make terragrunt/apps/local
make terragrunt/apps/contabo

# Get outputs (e.g., kubeconfig)
make terragrunt/network/contabo 1='output -json k3s_config | yq -p json -o yaml'

# Login to the cluster (kubectl via Dex OIDC)
make login                 # local env (default)
make login ENV=contabo     # production
```

> **kubectl access**: `make login` runs the Terraform-generated `oidc_login_setup_command_ops` output from `tf-root-paas` — it configures the `oidc` user (kubectl oidc-login exec plugin against `https://dex.<paas_base_domain>`), the `plateforme` cluster (`https://<paas_base_domain>:6443` + CA), and activates the `plateforme` context. Run it before any `kubectl` command. Requires the paas layer to be applied (state present).

### Secrets Management

```bash
# Edit secrets (SOPS + age, uses ssh-to-age from default flake shell)
# Edit secrets (SOPS + age, uses ssh-to-age from default flake shell)
# ./secrets is a symlink to ../secrets (org-404/secrets) — author THERE,
# or equivalently run sops from inside ../secrets. Rotation = 1 commit in
# ../secrets; no k3s-paas lockfile bump (k3s-paas takes no secrets input).
sops secrets/prod.yaml
sops secrets/local.yaml
sops secrets/darwin.yaml
```

## Key Conventions

### Nix / NixOS

- **Flake-based**: All NixOS and darwin configs are defined in `flake.nix`
- **Custom options**: The `paas.*` namespace is defined in `nixos-options/default.nix`
- **srvos**: Uses `numtide/srvos` for server-optimized NixOS defaults
- **nixos-generators**: Used for building qcow2 images
- **nix-darwin**: macOS configuration with libvirt, dnsmasq, and home-manager
- **linux-builder**: x86_64-linux cross-compilation via `nix.linux-builder` on Apple Silicon. It serves double duty as a Docker host (`DOCKER_HOST=tcp://127.0.0.1:2375`); see [Linux builder VM networking](#linux-builder-vm-networking) below.

### nix-darwin (macOS control host)

The macOS host runs several `launchd` daemons (configured in `nixos-darwin/configuration.nix`) that the local development flow depends on:

- **libvirtd + virtlogd**: Keep the local hypervisor running so the Terraform libvirt provider (`tf-modules-cloud/libvirt`) can provision the local NixOS VM during `terragrunt/cloud/local`.
- **dnsmasq**: Resolves `*.${dns.name}` to the kube IP (`kube.addr`), giving stable hostnames for local ingress hosts.
- **minio**: Local S3-compatible server on `127.0.0.1:9000` (console `:9001`, creds `minioadmin`/`minioadmin`). Used as the Longhorn backup target in the local environment: `tf-root-paas` passes it as `object_storage` → `tf-modules-k8s/longhorn` creates the `longhorn-s3-credentials` secret and sets `backupTarget = s3://...`.
- **pebble**: Local ACME server used as the cert-manager issuer in the `local` Let's Encrypt environment. Its root CA is imported into the macOS system keychain on activation.
- **litellm**: Local LLM gateway on `127.0.0.1:4000` exposing OpenCode Zen and the Z.ai GLM coding plan behind both OpenAI (`/v1/chat/completions`) and Anthropic-compatible (`/v1/messages`) endpoints. It is the **only** proxy for provider endpoints — no other adapter or translator sits in front of a provider. Unlike the daemons above it is a **user LaunchAgent managed by home-manager** (`launchd.agents.litellm` in `nixos-darwin/litellm.nix`, label `org.nix-community.home.litellm`), because it needs to read the user-scoped SOPS secrets; logs go to `~/Library/Logs/Litellm/`. No auth on the proxy (localhost trust); restart with `launchctl kickstart -k gui/$(id -u)/org.nix-community.home.litellm`. Claude Code and VS Code chat both use it instead of direct provider APIs. Only chat-completions-capable model ids can be served: litellm forwards that protocol upstream, so Responses-only ids (`muse-*`, `grok-4.x`, `gpt-*-luna`, `claude-haiku-5-5`, …) are not available at all.

#### Linux builder VM networking

The Nix `linux-builder` VM runs as a root LaunchDaemon (`org.nixos.linux-builder`) and doubles as the Docker host for project dev stacks. It has **two** NICs:

| NIC | Backend | Address | Reachable from macOS |
|-----|---------|---------|----------------------|
| `eth0` | SLiRP (`-netdev user`) | `10.0.2.15` (NAT) | Only the ports in `virtualisation.forwardPorts`: `31022` (SSH, used by `nix.buildMachines`) and `2375` (Docker API → `DOCKER_HOST`) |
| `eth1` | `vmnet-shared` (`nixos-darwin/configuration.nix`) | `192.168.2.x` via DHCP on host `bridge100` | **Every port**, natively |

SLiRP cannot forward arbitrary ports — `hostfwd` has no wildcard or range form, and QEMU refuses to start the whole VM if any one listed host port is already bound. The `vmnet-shared` NIC solves that: any service the guest listens on is reachable at its `bridge100` address, with no NixOS rebuild and no port list to maintain.

- Find the guest address with `linux-builder-ip` (a `writeShellScriptBin` in `nixos-darwin/configuration.nix`; reads the DHCP lease for the fixed MAC `de:ad:be:ef:aa:bb`, falling back to `arp`).
- Containers must publish on the guest's **wildcard** address — `"8787:8787"` in compose, *not* `"127.0.0.1:8787:8787"`. A loopback-bound container stays unreachable over vmnet even though the port is open.
- Requires QEMU to run as root, which the LaunchDaemon already does.
- Changing the NIC layout requires recreating the VM disk: `nix.linux-builder.ephemeral` is `false`, so `/var/lib/linux-builder/nixos.qcow2` is reused and the guest config would otherwise not be rebuilt.

**Docker CLI plugins come from Nix, not `~/.docker/cli-plugins`.** The `docker-client` package in `nixos-darwin/home-manager.nix` wraps the CLI with `DOCKER_CLI_PLUGIN_DIRS` pointing at the `docker-plugins` symlink farm (`docker-buildx` + `docker-compose`). Docker's **user** plugin dir `~/.docker/cli-plugins` takes *precedence* over those, so a stale entry there silently shadows the working Nix plugin.

This bit us once: two dead symlinks from a long-gone Rancher Desktop install (`~/.docker/cli-plugins/docker-{buildx,compose}` → `/Users/loic/.rd/bin/…`, dated Mar 2023) made *every* project fail at:

```
fork/exec /Users/loic/.docker/cli-plugins/docker-buildx: no such file or directory
```

Confusingly, `docker compose version` and `docker system info` still worked — the `compose` plugin itself resolved from Nix, but `docker compose build` shells out to `buildx`, which hit the dead user-level link. Diagnose and fix with:

```bash
docker system info --format '{{range .ClientInfo.Plugins}}{{.Name}} -> {{.Path}}{{"\n"}}{{end}}'
for f in ~/.docker/cli-plugins/*; do [ -e "$(readlink "$f")" ] || echo "dangling: $f"; done
```

Delete any dangling entry under `~/.docker/cli-plugins` — the Nix plugin farm is already on the search path and needs no link there. Nothing in this repo recreates those links, so once removed they stay gone.

**When `make bootstrap` restarts the builder — and when it does not.** `make bootstrap` runs `darwin-rebuild switch`, and nix-darwin only reloads a LaunchDaemon when its **plist content changes** (it diffs `/run/current-system/Library/LaunchDaemons/org.nixos.linux-builder.plist` against `/Library/LaunchDaemons/…`). The plist embeds the *store path* of `linux-builder-start`, so:

| Change | Plist diff? | VM restarted? |
|--------|-------------|---------------|
| Anything inside `nix.linux-builder.config` (QEMU args, guest config, `forwardPorts`) | **yes** — new `linux-builder-start` path | yes |
| `ephemeral`, `maxJobs`, `workingDirectory`, … | yes | yes |
| Nothing / host-side files only | no | **no** — stays up, no downtime |

So a stale VM after editing builder config was *not* a reload bug; the common trap is editing the config, then checking the VM without running `make bootstrap` at all — or having an earlier `darwin-rebuild` already consume the change, so the next bootstrap correctly finds nothing to do. Confirm a reload happened by watching for `reloading service org.nixos.linux-builder` in the output, and compare PIDs across the run:

```bash
sudo launchctl list | grep linux-builder          # first column = daemon PID
sudo ps -Ao pid,command | grep '[q]emu-system'    # VM process
```

**Relation to `cert-manager` and `internal-ca` modules** (`tf-root-paas`, local env only):

- `tf-root-paas` derives the cluster gateway IP from the ingress controller IP and points cert-manager at pebble: ACME URL `https://<gateway-ip>:14000/dir`.
- The pebble root CA is fetched from `https://<gateway-ip>:15000/roots/0` via `data.http`, injected as `internal_acme_ca_content`, and the `cert-manager` module publishes it as the `acme-internal-root-ca` ConfigMap (with `reflector.v1.k8s.emberstack.com` annotations) so pods trust pebble-issued certs.
- The `internal-ca` module (only applied when `cert_manager_letsencrypt_env == "local"`) patches CoreDNS to resolve the internal ingress hosts to the ingress controller IP.
- On Contabo, these daemons are not used: cert-manager targets Let's Encrypt staging/prod and `internal-ca` is skipped.

### Terraform / Terragrunt

- **4-layer architecture**: cloud → network → paas → apps
- **Local state**: Terragrunt uses local backend (`.terragrunt/<env>/<path>/terraform.tfstate`)
- **SOPS integration**: `sops_decrypt_file()` in `env.hcl` injects secrets as Terraform variables
- **Module composition**: `tf-root-*` modules compose `tf-modules-*` into deployable stacks
- **Helm releases**: Kubernetes apps deployed via `helm_release` with `atomic = true` and `take_ownership = true`
- **Kubernetes provider**: Uses `kubernetes_*` resources (not `kubectl` provisioner)
- **kubectl access**: Never look for or copy kubeconfig files manually. Cluster access is always via `make login` (or `make login ENV=contabo`) before any `kubectl` command. For debugging when OIDC auth fails, use the admin kubeconfig procedure in `/memories/repo/oauth2-proxy-subpath-bug.md`.

### Generated credentials & outputs

Service modules (supabase, appsmith, listmonk, etc.) often need a generated admin/login credential that the operator must use to sign in. Follow these conventions so the operator never has to ask for them:

- **Generate, don't hardcode**: Create admin/login credentials with `random_password` resources in the module, never inline literals. Wire them into the helm `values` / `kubernetes_secret` and re-expose them as `output ... { sensitive = true }` on the module, then thread matching sensitive outputs up through the `tf-root-*` composition module.
- **Always surface after apply**: After any apply that creates or rotates such outputs, proactively print the exact retrieval command(s) for the operator — do not wait to be asked. Use the standard output one-liner:

```bash
# Retrieve a sensitive/generated output (e.g. a generated admin password)
make terragrunt/apps/contabo 1='output -json <output_key>'
make terragrunt/apps/contabo 1='output -json <output_key_2>'
```

- **Include the login entry point**: Alongside the creds, print the URL the operator should open (e.g. `https://<app>.<paas_base_domain>/`) and any gotcha that affects login (e.g. "browser may have a cached Dex redirect — use incognito", "Kong basic-auth: pod restart required after secret rotation").

### Post-apply checklist for service modules

When a service-module apply finishes, verify and report in this order before declaring done:

1. Pods ready: `kubectl --context plateforme get pods -n <namespace>` — all `1/1 Running` (or expected count).
2. Helm release healthy: `helm --kube-context plateforme list -n <namespace> -a` — status `deployed` (not `pending-install` / `failed`).
3. Ingress reachable: `curl -sI -o /dev/null -w 'HTTP %{http_code}\n' https://<app>.<paas_base_domain>/` — expect a sane code (200/302/401 per the auth design), not a connection error.
4. Surface login credentials + URL (see **Generated credentials & outputs** above).

### Secrets

- **Wrapper inversion (2026-01)**: the private `../secrets` repo (org-404/secrets) is the *main flake* — it pins k3s-paas as a flake input and hosts the wrapper `flake.nix`/`Makefile`. k3s-paas is the public product and takes **no secrets input**. `make bootstrap` in k3s-paas delegates to `../secrets`, which (a) injects the real `darwin.yaml` via `secretsSopsFile` on `mkDarwinSystem`, and (b) adds `--override-input k3s-paas path:../k3s-paas` when the sibling checkout exists so the *working tree* is validated, not the lock pin.
- **SOPS + age**: Secrets encrypted with age keys derived from SSH keys
- **Two recipients**: Operator key + VM host key (for NixOS deployment)
- **Per-environment files**: `local.yaml`, `prod.yaml`, `darwin.yaml` — authored in `../secrets` only; `./secrets` is a symlink created by the dev shell (`plateforme-secrets` → `link-secrets`)
- **Standalone darwin eval**: `sops-defaults/darwin.yaml` (tracked placeholders) keeps `nix eval/build .#darwinConfigurations.*` working without `../secrets` — values are fake by design
- **Runtime secrets**: NixOS deploy module creates transient secrets on the VM via SOPS
- **Pin hygiene**: wrapper `flake.lock` = last-known-good; bump with `make -C ../secrets update` only after a green `make bootstrap`

### Kubernetes Platform

- **RKE2**: Single-node cluster with Canal CNI
- **Ingress**: NGINX ingress controller
- **TLS**: cert-manager with Let's Encrypt (staging/prod) or internal CA (local)
- **Auth**: Dex OIDC → oauth2-proxy → apps (GitHub org/team based)
- **Storage**: Longhorn with S3 backup target
- **DNS**: CoreDNS wildcard for internal hosts (local), Gandi for production

## Common Pitfalls

1. **Terragrunt cache permission denied**: After `make bootstrap`, the `result/` folder is owned by root. Delete it or `chown` to `$USER`.

2. **DNS cache issues**: After recreating VMs, clear Chrome DNS cache at `chrome://net-internals/#dns` or use different `dex_hostname`/`paas_hostname` per environment.

3. **RKE2 restart**: `terragrunt/network/<env>` changes trigger a long RKE2 service restart.

4. **Libvirt on macOS**: Requires `libvirtd` and `virtlogd` launchd daemons (configured in `nixos-darwin/configuration.nix`).

5. **x86_64 builds on Apple Silicon**: Use `make bootstrap-contabo` to start the linux-builder before building x86_64 images.

6. **SOPS decryption failures**: Ensure `SOPS_AGE_KEY` and `SOPS_AGE_RECIPIENTS` are set (done automatically in `nix develop` shell via `nixpkgs/plateforme-secrets/init-sops.sh`).

6b. **Never `darwin-rebuild switch` from k3s-paas standalone**: without the wrapper, `mkDarwinSystem` falls back to `sops-defaults/darwin.yaml` — *placeholder* values that would activate fake API keys onto the real machine. Always bootstrap via `make bootstrap` (delegates to `../secrets`, which injects the real `darwin.yaml` via `secretsSopsFile` and builds the sibling working tree via `--override-input`). Likewise never author secrets under `./secrets` — it is a symlink to `../secrets`, the single authoring copy.

7. **Service in the linux-builder VM unreachable from macOS**: Two separate causes, both required. (a) SLiRP only forwards the `virtualisation.forwardPorts` list — use the guest's `vmnet-shared` address from `linux-builder-ip` instead of trying to add forwards. (b) A container published on `127.0.0.1:PORT:PORT` is bound to guest loopback and stays unreachable over vmnet; publish on the wildcard (`PORT:PORT`). See [Linux builder VM networking](#linux-builder-vm-networking).

8. **`darwin-rebuild switch` fails with "path … does not exist" for a new `.nix` file**: the flake only sees git-tracked files. `git add` the new module before switching.

9. **`docker compose build` fails with `fork/exec ~/.docker/cli-plugins/docker-buildx: no such file or directory`**: a dangling user-level plugin symlink is shadowing the Nix-provided plugin. Delete it — see [Docker CLI plugins come from Nix](#linux-builder-vm-networking).

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `ENV_NAME` | Terragrunt environment name | `prod` |
| `ARCH` | Architecture for local libvirt | `aarch64` |
| `VARIANT` | Darwin builder variant | `builder` |
| `TARGET` | NixOS build target | `initial` |
| `SOPS_AGE_KEY` | Age private key for SOPS | Derived from `~/.ssh/id_ed25519` |
| `SOPS_AGE_RECIPIENTS` | Age public keys for SOPS | Derived from `~/.ssh/id_ed25519.pub` |

## Documentation

- [README.md](README.md) - Setup and usage instructions
- [docs/1-install.md](docs/1-install.md) - Installation guide
- [docs/2-help.md](docs/2-help.md) - FAQ and troubleshooting
- [docs/index.md](docs/index.md) - Architecture overview

## Related Skills

This repository has custom skills in `.agents/skills/`:
- `caveman*` - Token-efficient communication modes
- `cntb` - Contabo info retrieval via the `cntb` CLI (single source of truth for Contabo subscription info; no Contabo API/web console)
- `libvirt` - libvirt VM provisioning expertise
- `nix-platform` - Nix/NixOS/nix-darwin practices
- `sops-secrets-platform` - SOPS + age secrets management
- `terraform-engineer` - Terraform conventions
- `terragrunt-platform` - Terragrunt orchestration

## Custom Agents

Custom agent sources live in `.agents/local-skills/agents/` (`.agent.md`, committed like the rest of `local-skills`). Each agent has a focused role and a minimal tool set. All agents load the `caveman` skill for token-efficient output; reviewers also load `caveman-review`.

`make agents-update` copies them verbatim into two **gitignored mirrors**: `.github/agents/` (VS Code) and `.claude/agents/` (Claude Code). The `agents/` subdir is ignored by `npx skills add`, so `make skills-update` is unaffected. The same source file serves both runtimes, so the frontmatter is bilingual:

- `name` — kebab-case (Claude requirement, harmless in VS Code)
- `tools` — union of both vocabularies: VS Code names (`read`, `execute`, `search`, `web`, `agent`, extension ids, `mcp-server/*`) + Claude names (`Read`, `Bash`, `Grep`, `Glob`, `Agent`, `WebSearch`, `WebFetch`, `mcp__chrome-devtools`); each runtime ignores names it doesn't know
- `model` — **omitted**: one scalar cannot be valid for both runtimes. Claude subagents take `CLAUDE_CODE_SUBAGENT_MODEL` (glm flash); VS Code falls back to its default model
- `permissionMode` / `argument-hint` / `skills` — VS Code-only keys, ignored by Claude

```bash
make agents-update   # cp .agents/local-skills/agents/*.agent.md -> .github/agents/ + .claude/agents/
```

| Agent | Role | When to use |
|-------|------|-------------|
| `orchestrator` | Default entry point: routes tasks to the right specialist; falls back to general work itself in caveman full mode | Start any task without a specialist pre-selected |
| `cloud-enabler` | Bootstrap and provision cloud/libvirt VMs, images, and initial connectivity | Layer-1 (cloud) Terragrunt changes, VM provisioning, image builds |
| `cloud-architect` | Plan cross-layer infrastructure and application architecture, and prepare validated deployment, rollback, and release plans | New features, environment changes, ADRs, design docs, and exact preflight/execution steps for operators |
| `platform-implementer` | Implement configurations across SOPS, Terragrunt, Terraform, and providers | Approved implementation tasks that touch multiple layers |
| `service-deployer` | Deploy and operate helm-based Kubernetes services serving direct business cases (n8n, supabase, appsmith, listmonk, smtp-relay, postgres, valkey, mongodb, minio) | Add/tune/debug service modules under `tf-modules-services/` and `tf-root-apps`, layer-4 (apps) Terragrunt changes |
| `architecture-reviewer` | Review platform boundaries, dependencies, resilience, security, and tradeoffs | Design decisions and architecture-level change review |
| `iac-reviewer` | Review Terraform, Terragrunt, Nix, Helm, Kubernetes, and SOPS secret-wiring plans or diffs | After infrastructure changes or before apply |
| `nix-maintainer` | Maintain and debug Nix, nix-darwin, and NixOS configs | Nix evals, builds, store analysis, option lookups |
| `ai-architect` | Design AI agentic systems: agents, skills, prompts, MCP servers, team workflows | Search/install/customize agentic assets, add MCP servers, design agent teams, self-test workflows |

## MCP Servers

Configured in `.vscode/mcp.json` and available to agents that list them in `tools`:

| Server | Purpose |
|--------|---------|
| `kubernetes` | Read-only cluster state (pods, services, ingress) via `kubectl`-style MCP |
| `chrome-devtools` | Browser automation for OAuth2-wall checks and UI validation |
| `terraform` | Terraform/Terragrunt plan, validate, and inspect via MCP |
| `agent-lsp` | LSP orchestration for Nix, Terraform, YAML, Bash, JSON, Dockerfile, Helm, Markdown |
| `github` | GitHub API for repo/team/secret debugging (uses `GITHUB_TOKEN` env var) |

**Note**: `agent-lsp` expects the `agent-lsp` binary on your `PATH` (install via the project's install script or package manager). The LSP servers themselves (`nil`, `terraform-ls`, `yaml-language-server`, etc.) are provided by the `devShells.default` and home-manager packages.

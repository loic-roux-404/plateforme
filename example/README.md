# Example wrapper: bootstrap the plateforme stack on your Mac

This directory is a **template of the private wrapper repo** that drives the
whole stack. The public [plateforme](https://github.com/loic-roux-404/plateforme)
flake builds the macOS control host (nix-darwin) and the NixOS VM images, but
takes **no secrets input** — your secrets live in a private repo shaped like
this one, which pins plateforme and injects the real SOPS file at build time.

Copy this directory out to its own **private** git repo, never commit it back
with real values.

## Layout

```
├── flake.nix               # wrapper: pin plateforme + inject darwin.yaml + your identity
├── Makefile                # bootstrap / update / doctor
├── .sops.yaml              # creation rules — YOUR age recipient
├── secrets-skeleton/       # plaintext skeletons; you encrypt copies of these
│   ├── darwin.yaml         # macOS home-manager secrets
│   └── local.yaml          # local libvirt env secrets
└── test.sh                 # one-shot validation (throwaway key, no switch)
```

## 0. Prerequisites

- macOS, Apple Silicon (Intel: use `VARIANT=builder-x86` everywhere)
- [Nix with flakes](https://install.determinate.systems/nix) (`curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh`)
- An **ed25519 SSH key without passphrase** at `~/.ssh/id_ed25519`
  (`ssh-keygen -t ed25519` if you have none)
- Sibling checkouts — plateforme's dev shell expects the wrapper repo to sit
  next to it **named `secrets`**:

```
your-dir/
├── plateforme/   # git clone git@github.com:loic-roux-404/plateforme.git
└── secrets/      # this template, copied out (private repo)
```

## 1. Create your wrapper repo

```bash
cd your-dir
git clone git@github.com:loic-roux-404/plateforme.git
cp -r plateforme/example secrets
cd secrets && git init
```

## 2. Derive your age key and wire the recipient

```bash
# nix shell for the tools if needed: nix shell nixpkgs#ssh-to-age
ssh-to-age < ~/.ssh/id_ed25519.pub      # public recipient — goes in .sops.yaml
```

Put that string in `.sops.yaml` in place of `__YOUR_AGE_RECIPIENT__`.

## 3. Set your identity

Edit the `let` block at the top of `flake.nix`: `user` (your macOS short
name, `whoami`) and `githubUser` (your GitHub login).

## 4. Encrypt the secrets skeletons

```bash
cp secrets-skeleton/darwin.yaml darwin.yaml
sops encrypt -i darwin.yaml
# for the local libvirt env (step 7), also:
cp secrets-skeleton/local.yaml local.yaml
sops encrypt -i local.yaml
```

Dummy values are fine for a first bootstrap — every consumer tolerates empty
strings. Fill real ones later with `sops darwin.yaml` (never plaintext).

## 5. Bootstrap the macOS host

```bash
make doctor      # proves your key opens darwin.yaml
make bootstrap   # build + darwin-rebuild switch (sudo)
```

You get: home-manager environment (shells, git, editors, k8s/terraform
tooling), libvirt + dnsmasq + minio launchd daemons, and the dev shells.

Dev loop against a local plateforme checkout:

```bash
PLATFORM_DIR=../plateforme make bootstrap   # builds the working tree
make update                                  # bump the pin, only after green
```

## 6. Build the NixOS VM image

```bash
cd ../plateforme
nix develop            # sops env + ./secrets symlink, terraform, terragrunt
make build             # TARGET=initial (default) → result/nixos.qcow2
```

`result/nixos.qcow2` is what the libvirt layer consumes; terragrunt fails the
apply if it is missing.

## 7. Bring up the local libvirt environment

From the plateforme dev shell, apply the four layers in order:

```bash
make terragrunt/cloud/local     # provision the local VM
make terragrunt/network/local   # DNS, Nix deploy, fetch kubeconfig
make terragrunt/paas/local      # cert-manager, dex, longhorn, ...
make terragrunt/apps/local      # n8n, supabase, ...
make login                      # kubectl via Dex OIDC
```

## 8. Re-enable the AI stack (optional)

The template flake sets `paas.aiStack.enable = false` — the litellm gateway,
claude-code and VS Code chat models otherwise need `opencode_api_key` /
`zai_api_key` in darwin.yaml. To enable: delete that line in `flake.nix`,
uncomment the two keys in the skeleton, re-encrypt, `make bootstrap`.

## Validate the template itself

```bash
./test.sh   # throwaway age key + dummy secrets; builds, never switches
```

# AGENTS.md

Guidance for AI coding agents working in this repository.

## Agent Operating Contract

Follow this contract for every task.

### Mandatory skill loading

Read the relevant `.agents/skills/*/SKILL.md` before editing. Always load `caveman`. Load these additional skills when applicable:

| Area | Required skill |
|---|---|
| Commits and changelogs | `caveman-commit` |
| Code, IaC, or design review | `caveman-review` |
| Nix, NixOS, flakes, nix-darwin | `nix-platform` |
| Terraform modules or providers | `terraform-engineer` |
| Terragrunt roots, layers, environments | `terragrunt-platform` |
| SOPS, age, credentials, secret wiring | `sops-secrets-platform` |
| Libvirt, QEMU, local VM networking | `libvirt` |
| Gemini API work | `gemini-interactions-api` |

Agent role definitions live in `.agents/agents/`.

### Caveman mode — required

Use Caveman mode for plans, progress, reviews, commit messages, and final responses.

- Short sentences. Concrete words. No filler.
- State result first. Then evidence. Then next action.
- Keep code, paths, commands, identifiers, and warnings exact.
- Expand only for requested rationale, design, or incident analysis.
- Never trade safety or correctness for brevity.

### Execution protocol

1. Read relevant files and adjacent modules first.
2. Make the smallest coherent change.
3. Keep environment values out of reusable modules.
4. Never expose, decrypt, print, copy, or commit secrets.
5. Validate the changed layer before declaring success.
6. Report changed files, commands run, validation result, and remaining risks.

### High-risk operations

Require explicit operator approval before:

- `terraform apply`, `terragrunt apply`, `destroy`, import, or state operations.
- Production NixOS deployment, RKE2 restart, or node change.
- Kubernetes deletion, Helm upgrade/uninstall, or storage migration.
- DNS, TLS, OAuth/Dex, access-policy, firewall, or secret changes.

For plan-only tasks, use read-only commands. Never imply a plan was applied.

## Project Overview

This is a Kubernetes PaaS infrastructure project. It deploys a single-node RKE2 cluster on Contabo VPS for production or a local libvirt VM for development and testing.

Core stack:

- NixOS for immutable infrastructure, VM images, and macOS tooling.
- Terraform and Terragrunt for provisioning and platform/application deployment.
- SOPS and age for secrets management.
- RKE2, Dex, oauth2-proxy, cert-manager, and Longhorn for the Kubernetes platform.

## Architecture

Deployment order is mandatory:

```text
cloud → network → paas → apps
```

- `nixos/`: NixOS system and deployment configuration.
- `nixos-darwin/`: nix-darwin, Home Manager, and Crush configuration.
- `secrets/`: SOPS-encrypted `local.yaml`, `prod.yaml`, and `darwin.yaml`.
- `terragrunt/cloud/`: VM provisioning.
- `terragrunt/network/`: DNS, Nix deploy, and kubeconfig retrieval.
- `terragrunt/paas/`: Kubernetes platform components.
- `terragrunt/apps/`: deployed applications.
- `tf-modules-*`: reusable Terraform modules.
- `tf-root-*`: composition modules.

## Common Commands

```bash
# Development environment
nix develop

# Nix validation
nix flake check

# Build local or Contabo images
nix build .#nixosConfigurations.default --system aarch64-linux
nix build .#nixosConfigurations.default --system x86_64-linux

# Bootstrap Darwin builders
make bootstrap
make bootstrap-contabo

# Terragrunt layers
make terragrunt/cloud/local
make terragrunt/cloud/contabo
make terragrunt/network/local
make terragrunt/network/contabo
make terragrunt/paas/local
make terragrunt/paas/contabo
make terragrunt/apps/local
make terragrunt/apps/contabo

# Edit encrypted secrets
sops secrets/local.yaml
sops secrets/prod.yaml
sops secrets/darwin.yaml
```

## Platform Conventions

- Use flake-based Nix configuration and the `paas.*` custom-option namespace.
- Preserve the four-layer deployment order.
- Use declarative Terraform, Kubernetes resources, and Helm releases; avoid shell provisioners.
- Helm releases use atomic deployment and explicit ownership.
- Put runtime credentials in SOPS-backed paths only.
- Prefer small, composable, idempotent modules with explicit inputs, outputs, dependencies, and ownership.
- Do not hard-code production values in reusable modules.

## Quality Gates

Run the narrowest relevant checks:

| Changed area | Minimum validation |
|---|---|
| Nix / NixOS / Darwin | `nix flake check` and evaluation or target build |
| Terraform | `terraform fmt -check` and `terraform validate` |
| Terragrunt | `terragrunt hclfmt --check` and `terragrunt validate` |
| Helm / Kubernetes | Render or validate manifests before apply |
| Shell | `shellcheck` when available |
| Documentation | Verify commands, paths, and environment names |

Do not say a check passed unless it ran successfully. If it cannot run, state why and provide the exact command.

## Definition of Done

A task is done when:

- The relevant skill definitions were read and applied.
- The smallest relevant validation completed.
- Documentation changed when behavior or operator workflow changed.
- No plaintext secret, credential, kubeconfig, or private endpoint was added.
- The final report uses Caveman mode and names any remaining risk.

## Common Pitfalls

- `result/` may be root-owned after bootstrap; remove it or return ownership to the active user.
- VM recreation can leave browser DNS caches stale.
- Network-layer changes may restart RKE2 and take time.
- Apple Silicon needs `make bootstrap-contabo` before x86_64 builds.
- SOPS requires `SOPS_AGE_KEY` and `SOPS_AGE_RECIPIENTS`; `nix develop` initializes them.

## Environment Variables

| Variable | Purpose | Default |
|---|---|---|
| `ENV_NAME` | Terragrunt environment | `prod` |
| `ARCH` | Local libvirt architecture | `aarch64` |
| `VARIANT` | Darwin builder variant | `builder` |
| `TARGET` | NixOS build target | `initial` |
| `SOPS_AGE_KEY` | SOPS age private key | Derived from `~/.ssh/id_ed25519` |
| `SOPS_AGE_RECIPIENTS` | SOPS age public keys | Derived from `~/.ssh/id_ed25519.pub` |

## Documentation

- `README.md`: setup and usage.
- `docs/1-install.md`: installation.
- `docs/2-help.md`: troubleshooting.
- `docs/index.md`: architecture overview.

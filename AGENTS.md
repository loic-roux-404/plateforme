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
- **AI development stack** (Crush CLI assistant + VS Code, for now)

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
│   ├── crush.nix             # Crush AI assistant config (AI stack: Crush + VS Code)
│   └── user-default.nix      # Default user settings (homebrew, shell)
├── nixos-options/            # Custom NixOS option definitions (paas.*)
├── nix-lib/                  # Nix library functions
│   └── mkDarwinSystem.nix    # Darwin system builder
├── nix-flake/                # Flake utilities
│   └── init-sops.sh          # SOPS age key setup script
├── secrets/                  # SOPS-encrypted secrets
│   ├── local.yaml            # Local environment secrets
│   ├── prod.yaml             # Production secrets
│   └── darwin.yaml           # Darwin/macOS secrets
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

### Nix / NixOS

```bash
# Enter dev shell (includes terraform, terragrunt, sops, kubectl, helm)
nix develop

# Build NixOS qcow2 image for local libvirt
nix build .#nixosConfigurations.default --system aarch64-linux

# Build for x86_64 (Contabo)
nix build .#nixosConfigurations.default --system x86_64-linux

# Build and switch darwin configuration
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
make terragrunt/network/contabo TF_CMD='output -json k3s_config | yq -p json -o yaml'
```

### Secrets Management

```bash
# Edit secrets (SOPS + age, uses ssh-to-age from default flake shell)
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
- **linux-builder**: x86_64-linux cross-compilation via `nix.linux-builder` on Apple Silicon

### nix-darwin (macOS control host)

The macOS host runs several `launchd` daemons (configured in `nixos-darwin/configuration.nix`) that the local development flow depends on:

- **libvirtd + virtlogd**: Keep the local hypervisor running so the Terraform libvirt provider (`tf-modules-cloud/libvirt`) can provision the local NixOS VM during `terragrunt/cloud/local`.
- **dnsmasq**: Resolves `*.${dns.name}` to the kube IP (`kube.addr`), giving stable hostnames for local ingress hosts.
- **minio**: Local S3-compatible server on `127.0.0.1:9000` (console `:9001`, creds `minioadmin`/`minioadmin`). Used as the Longhorn backup target in the local environment: `tf-root-paas` passes it as `object_storage` → `tf-modules-k8s/longhorn` creates the `longhorn-s3-credentials` secret and sets `backupTarget = s3://...`.
- **pebble**: Local ACME server used as the cert-manager issuer in the `local` Let's Encrypt environment. Its root CA is imported into the macOS system keychain on activation.

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

### Secrets

- **SOPS + age**: Secrets encrypted with age keys derived from SSH keys
- **Two recipients**: Operator key + VM host key (for NixOS deployment)
- **Per-environment files**: `secrets/local.yaml`, `secrets/prod.yaml`, `secrets/darwin.yaml`
- **Runtime secrets**: NixOS deploy module creates transient secrets on the VM via SOPS

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

6. **SOPS decryption failures**: Ensure `SOPS_AGE_KEY` and `SOPS_AGE_RECIPIENTS` are set (done automatically in `nix develop` shell via `nix-flake/init-sops.sh`).

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
- `libvirt` - libvirt VM provisioning expertise
- `nix-platform` - Nix/NixOS/nix-darwin practices
- `sops-secrets-platform` - SOPS + age secrets management
- `terraform-engineer` - Terraform conventions
- `terragrunt-platform` - Terragrunt orchestration

## Custom Agents

This repository has custom agents in `.agents/agents/`. Each agent has a focused role and a minimal tool set. All agents load the `caveman` skill for token-efficient output; reviewers also load `caveman-review`.

| Agent | Role | When to use |
|-------|------|-------------|
| `orchestrator` | Default entry point: routes tasks to the right specialist; falls back to general work itself in caveman full mode | Start any task without a specialist pre-selected |
| `cloud-enabler` | Bootstrap and provision cloud/libvirt VMs, images, and initial connectivity | Layer-1 (cloud) Terragrunt changes, VM provisioning, image builds |
| `cloud-architect` | Plan cross-layer infrastructure and application architecture | New features, environment changes, ADRs, design docs |
| `platform-implementer` | Implement configurations across SOPS, Terragrunt, Terraform, and providers | Approved implementation tasks that touch multiple layers |
| `service-operator` | DevOps for helm-based services (databases, n8n, smtp-relay, supabase) | Add/tune/debug service modules under `tf-modules-services/` and `tf-root-apps` |
| `release-operator` | Prepare validated deployment, rollback, and release plans | Operator needs exact preflight and execution steps |
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

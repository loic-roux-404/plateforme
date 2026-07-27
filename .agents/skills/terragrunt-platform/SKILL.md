---
name: terragrunt-platform
description: >
  Terragrunt orchestration conventions for loic-roux-404/plateforme.
  Covers the four-layer apply sequence (cloud → network → paas → apps),
  env.hcl + root.hcl pattern, sops_decrypt_file() inline secret injection,
  local state backend, the ARCH env var pattern, and Makefile targets.
  Use when adding a new environment, wiring a new tf-module into a Terragrunt root,
  debugging state or secret issues, or reasoning about apply order dependencies.
metadata:
  version: "1.0.0"
  domain: infrastructure
  triggers: >
    terragrunt, terragrunt.hcl, env.hcl, root.hcl, find_in_parent_folders,
    sops_decrypt_file, local backend, terragrunt/cloud, terragrunt/network,
    terragrunt/paas, terragrunt/apps, ARCH, libvirt_qcow_source, make terragrunt
  role: platform-engineer
  scope: implementation
  output-format: code
---

## Repository Layout

This is a **mono-repo** with clear separation between live config (`terragrunt/`) and reusable modules (`tf-modules-*`, `tf-root-*`):

```
plateforme/
├── root.hcl                    # global backend + input propagation
├── Makefile                    # primary operator interface
├── terragrunt/
│   ├── cloud/
│   │   ├── contabo/            # Contabo VPS env
│   │   └── local/              # libvirt/QEMU local VM env
│   ├── network/
│   ├── paas/
│   ├── apps/
│   ├── environments/           # possibly shared env references
│   └── profiles/               # possibly hardware/arch profiles
├── tf-root-apps/
├── tf-root-network/
├── tf-root-paas/
├── tf-modules-cloud/
├── tf-modules-github/
├── tf-modules-k8s/
├── tf-modules-monitoring/
├── tf-modules-nix/
└── tf-modules-services/
```

The `terraform/` directory at root is separate from `terragrunt/` — it likely holds standalone Terraform configs or scratch/bootstrap code outside the Terragrunt lifecycle.

## Four-Layer Apply Sequence

Apply **strictly in this order**. Each layer depends on outputs from the previous:

```bash
# 1. Provision VPS or local VM, outputs node_ip
make terragrunt/cloud/contabo

# 2. Install k3s/RKE2, configure DNS — outputs k3s_config
make terragrunt/network/contabo

# Wait for RKE2 bootstrap (documented: ~180s)
sleep 180

# 3. Deploy platform services: Dex, cert-manager, oauth2-proxy
make terragrunt/paas/contabo

# 4. Configure GitHub repos and OIDC variables
make terragrunt/apps/contabo
```

For local dev, substitute `contabo` → `local`. The `profiles/` and `environments/` directories suggest additional cross-cutting configuration that may be included via `find_in_parent_folders()`.

## `env.hcl` Structure (Canonical Pattern)

Every environment leaf directory contains exactly:

```hcl
locals {
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/contabo.yaml")))
  env         = "contabo"
  input_vars  = {
    # All Terraform inputs for this layer/env combination
    node_ip  = local.secret_vars.node_ip
    arch     = get_env("ARCH", "x86_64-linux")
  }
}
```

The `ARCH` env var controls NixOS target architecture (default `x86_64-linux`, override for aarch64). This flows into `tf-modules-nix` to select the correct Nix build closure.

## `terragrunt.hcl` Leaf Pattern

Each environment leaf (`terragrunt/<layer>/<env>/terragrunt.hcl`) follows:

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}//tf-root-<layer>"
}
```

The double-slash (`//`) is Terragrunt's separator between the repo root and the module subdirectory. Source always points to a local `tf-root-*` directory, never a remote URL or Git tag.

## Makefile as Primary Interface

Operators never run `terragrunt` directly. All invocations go through `make`:

```makefile
# Pattern (inferred from SKILL.md + Makefile)
terragrunt/%:
    @cd terragrunt/$* && terragrunt apply -auto-approve
```

The default command is `apply -auto-approve`. Override by modifying the Makefile or running terragrunt directly inside the working directory for plan-only or output operations:

```bash
# Get outputs from a deployed layer
cd terragrunt/network/contabo && terragrunt output -json k3s_config | yq -p json -o yaml
```

## Nix DevShell is Mandatory

The entire operator workflow assumes `nix develop` (or `direnv allow` with `.envrc`):
- `SOPS_AGE_KEY` is injected by the devShell — SOPS decryption is impossible without it
- All tools (`terragrunt`, `terraform`, `kubectl`, `sops`, `age`, `yq`) are pinned via `flake.nix`
- `flake.lock` pins exact tool versions — never install tools globally; always use the devShell

```bash
# Correct workflow
nix develop  # or: direnv allow (reads .envrc which calls nix develop)
make terragrunt/cloud/contabo
```

## State Backup Protocol

Since state is local with no locking, follow this before any destructive operation:

```bash
# Backup before apply on existing infrastructure
cp -r .terragrunt/ .terragrunt.bak-$(date +%Y%m%d-%H%M%S)/

# Restore if apply goes wrong
cp -r .terragrunt.bak-<timestamp>/ .terragrunt/
```

State path schema: `.terragrunt/<env>/<layer>/terraform.tfstate`

## Adding a New Environment (e.g., `hetzner`)

```bash
# 1. Create layer configs
mkdir -p terragrunt/cloud/hetzner
cat > terragrunt/cloud/hetzner/env.hcl << 'EOF'
locals {
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/hetzner.yaml")))
  env         = "hetzner"
  input_vars  = { ... }
}
EOF

cat > terragrunt/cloud/hetzner/terragrunt.hcl << 'EOF'
include "root" { path = find_in_parent_folders("root.hcl") }
terraform { source = "${get_repo_root()}//tf-root-cloud-hetzner" }
EOF

# 2. Create and encrypt secrets
sops secrets/hetzner.yaml

# 3. Repeat for network/, paas/, apps/ layers
```

## `exclude_from_copy` in `root.hcl`

The global `root.hcl` excludes Nix build artifacts from Terragrunt's working copy:

```hcl
terraform {
  exclude_from_copy = [
    ".git", "result/Library", "result/darwin", "result/Applications",
    "result/patches", "result/sw", "result/user", "result/etc",
    "*.nix", ".direnv"
  ]
}
```

This is critical because `tf-modules-nix` lives alongside `.nix` files. Without this exclusion, Terragrunt would copy Nix expressions and large `result/` symlinks into the `.terragrunt-cache/`, causing corruption or unexpected behavior.

---

## Notes — Technical Debt & Observations

**🔴 No state locking.** Local backend has no locking mechanism. On a single-operator project this is acceptable, but a concurrent CI apply (if ever added) would corrupt state. Mitigation: use `terraform_http` backend or migrate to a lightweight remote like Terraform Cloud free tier if multi-operator access is needed.

**🔴 No provider version pinning in modules.** Most `tf-modules-*` lack `terraform { required_providers {} }` blocks. Tool versions are pinned via `flake.lock` (Nix), which pins the `terraform` binary version, but provider plugin versions are not declared in HCL. This means `terraform init` may pull different provider versions on different machines if `.terraform.lock.hcl` is absent or gitignored.

**🟡 No drift detection workflow.** There is no `make plan` target or CI step that runs `terragrunt plan` against live infrastructure to detect drift. Since the Contabo VPS is live infrastructure, drift can accumulate silently. Consider adding a `make plan/<layer>/<env>` target.

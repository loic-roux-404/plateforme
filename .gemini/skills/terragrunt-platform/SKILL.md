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

## Layer Apply Order

Always apply in this order; each layer depends on outputs from the previous:

```bash
make terragrunt/cloud/<env>    # provisions VM or VPS instance, outputs node_ip
make terragrunt/network/<env>  # installs k3s/rke2 config, DNS, outputs k3s_config
sleep 180                      # wait for RKE2 bootstrap (documented in README)
make terragrunt/paas/<env>     # installs platform services (Dex, cert-manager)
make terragrunt/apps/<env>     # configures GitHub repos, OIDC variables
```

## env.hcl Convention

Every environment root contains an `env.hcl` with exactly:
```hcl
locals {
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/<env>.yaml")))
  env         = "<env-name>"
  input_vars  = {
    # flat key-value map passed as Terraform inputs
  }
}
```

`sops_decrypt_file()` requires `SOPS_AGE_KEY` to be set — this is only available inside `nix develop`.
**Never run `terragrunt apply` outside the nix devShell.**

## root.hcl Pattern

State is always local:
```hcl
remote_state {
  backend = "local"
  config = {
    path = "${get_parent_terragrunt_dir()}/.terragrunt/${local.env.locals.env}/${path_relative_to_include()}/terraform.tfstate"
  }
}
```

State files live in `<repo-root>/.terragrunt/<env>/<layer>/terraform.tfstate`.
These are gitignored. Back them up manually before destructive operations.

## Adding a New Environment

1. Create `terragrunt/<layer>/<newenv>/env.hcl` and `terragrunt.hcl`
2. Create `secrets/<newenv>.yaml` with `sops secrets/<newenv>.yaml`
3. Point `terragrunt.hcl` source at the appropriate `tf-modules-*` path
4. Set `env = "<newenv>"` in `env.hcl` locals

## Makefile Target Pattern

```make
$(TERRAGRUNT_FILES):
    @terragrunt --working-dir $@ $(1)
```

`$(1)` is the first Make argument, defaulting to `apply -auto-approve`.
To run a different command: `make terragrunt/network/contabo TF_CMD='output -json k3s_config | yq -p json -o yaml'`
Note: this uses `1:=apply -auto-approve` — passing `TF_CMD` actually requires the Makefile to be updated, the README example uses a non-standard override pattern.

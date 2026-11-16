# Pin resolution lives here as ENV VARS set by the `paas` script:
#   PLATEFORME_REV   locked commit (from the wrapper flake.lock) — git source ?ref
#   PLATFORM_DIR     set → use that plateforme checkout instead of GitHub
# Units read these via `include "root" { expose = true }` → include.root.locals.*
# Raw terragrunt (not via paas): PLATEFORME_REV defaults to `main` (floating);
# pin it explicitly with PLATEFORME_REV=$(jq -r .nodes.plateforme.locked.rev flake.lock)
locals {
  # root = wrapper/terragrunt (dir of this file). NOTE: get_parent_terragrunt_dir()
  # returns the UNIT dir here (no parent terragrunt.hcl above units) — never use
  # it to climb; find_in_parent_folders("root.hcl") is the reliable anchor.
  root   = dirname(find_in_parent_folders("root.hcl"))
  env    = read_terragrunt_config("env.hcl")
  dir    = get_env("PLATFORM_DIR", "")
  # default = main so raw terragrunt runs work; caveat: they float on the
  # branch (no pin). `paas`/Makefile always export the locked rev.
  rev    = get_env("PLATEFORME_REV", "main")
  base   = local.dir != "" ? local.dir : "git::https://github.com/loic-roux-404/plateforme.git"
  suffix = local.dir != "" ? "" : "?ref=${local.rev}"
}

remote_state {
  backend = "local"
  config = {
    path = "${local.root}/.terragrunt/${local.env.locals.env}/${path_relative_to_include()}/terraform.tfstate"
  }

  generate = {
    path = "backend.tf"
    if_exists = "overwrite"
  }
}

# exclude_from_copy only applies to the PLATFORM_DIR local-path case (terragrunt
# copies the repo root from the first `//`); git sources bypass it.
terraform {
  exclude_from_copy = [
    ".git",
    ".direnv",
    ".terragrunt",
    ".terragrunt-cache",
    # nested wrapper clone (when PLATFORM_DIR points at plateforme with the
    # wrapper cloned inside): SOPS files + .terragrunt-cache recursion
    "secrets",
    "secrets-skeleton",
    "docs",
    "example",
    "nixos",
    "nixos-darwin",
    "nixos-options",
    "nix-lib",
    "nixpkgs",
    "result",
    "result/*",
    "*.nix"
  ]
}

inputs = local.env.locals.input_vars

# Milestone 2 (after local cloud+network is green): paas/local and apps/local
# units follow the same shape as cloud/local + network/local, with env.hcl
# pulling cross-layer outputs via dependencies.hcl.

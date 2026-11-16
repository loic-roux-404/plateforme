locals {  
  env = read_terragrunt_config("env.hcl")
}

remote_state {
  backend = "local"
  config = {
    path = "${get_parent_terragrunt_dir()}/.terragrunt/${local.env.locals.env}/${path_relative_to_include()}/terraform.tfstate"
  }

  generate = {
    path = "backend.tf"
    if_exists = "overwrite"
  }
}

terraform {
 exclude_from_copy = [
    ".git",
    ".direnv",
    ".terragrunt",
    ".terragrunt-cache",
    # nested wrapper clone: SOPS files + its own 1G .terragrunt-cache recursion
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
    "result/Library",
    "result/darwin",
    "result/Applications",
    "result/patches",
    "result/sw",
    "result/user",
    "result/etc",
    "*.nix"
  ]
}

inputs = local.env.locals.input_vars

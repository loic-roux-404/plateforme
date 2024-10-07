locals {
  env          = "local"
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  secret_vars  = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/${local.env}.yaml")))
  flake_dir    = dirname(find_in_parent_folders("flake.nix"))
  input_vars = {
    gandi_token              = ""
    machine                  = local.dependencies.dependency.cloud.outputs
    nix_flake                = "${local.flake_dir}#deploy"
    nix_flake_reset          = "${local.flake_dir}#initial"
  }
}

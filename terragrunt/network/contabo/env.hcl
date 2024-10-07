
locals {
  env = get_env("ENV_NAME", "prod")
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/${local.env}.yaml")))
  flake_dir = dirname(find_in_parent_folders("flake.nix"))
  input_vars = {
    machine = local.dependencies.dependency.cloud.outputs
    paas_base_domain = local.secret_vars.paas_base_domain
    gandi_token = local.secret_vars.gandi_token
    nix_flake = "${local.flake_dir}#deploy-contabo"
    nix_flake_reset = "${local.flake_dir}#initial-contabo"
  }
}

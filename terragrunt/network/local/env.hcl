locals {
  env = "local"
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/${local.env}.yaml")))
  flake_dir = dirname(find_in_parent_folders("flake.nix"))
  input_vars = {
    gandi_token = ""
    machine = local.dependencies.dependency.cloud.outputs
    nix_flake = "${local.flake_dir}#deploy"
    reset_nix_flake = "${local.flake_dir}#reset"
    tailscale_oauth_client = local.secret_vars.tailscale_oauth_client
    tailscale_tailnet = local.secret_vars.tailscale_tailnet
    tailscale_trusted_device = local.secret_vars.tailscale_trusted_device
  }
}

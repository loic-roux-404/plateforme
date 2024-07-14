
locals {
  env = get_env("ENV_NAME", "prod")
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/${local.env}.yaml")))
  input_vars = {
    machine = local.dependencies.dependency.cloud.outputs
    paas_base_domain = local.secret_vars.paas_base_domain
    tailscale_oauth_client = local.secret_vars.tailscale_oauth_client
    tailscale_tailnet = local.secret_vars.tailscale_tailnet
    tailscale_trusted_device = local.secret_vars.tailscale_trusted_device
  }
}

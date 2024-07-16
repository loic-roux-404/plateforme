locals {
  env = "local"
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/${local.env}.yaml")))
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  input_vars = {
    letsencrypt_env = local.env
    cert_manager_letsencrypt_env = local.env
    cert_manager_email = local.secret_vars.cert_manager_email
    github_token = local.secret_vars.github_token
    github_client_id = local.secret_vars.github_client_id
    github_client_secret = local.secret_vars.github_client_secret
    tailscale_operator_hostname = local.dependencies.dependency.network.outputs.tailscale_operator_hostname
  }
}

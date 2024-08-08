locals {
  env          = get_env("ENV_NAME", "prod")
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  secret_vars  = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/${local.env}.yaml")))
  input_vars = merge(local.dependencies.dependency.network.outputs, local.secret_vars, {
    cert_manager_letsencrypt_env = local.env
  })
}

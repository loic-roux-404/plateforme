locals {
  env = get_env("ENV_NAME", "prod")
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/${local.env}.yaml")))
  input_vars = {
    contabo_credentials = local.secret_vars.contabo_credentials
    contabo_instance = local.secret_vars.contabo_instance
    node_hostname = "k3s-paas-master-0"
  }
}

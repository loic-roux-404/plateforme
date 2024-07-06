terraform {
  source = "${include.envcommon.locals.base_source_url}"
}

locals {
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/prod.yaml")))
}

inputs = merge(
  local.secret_vars,
  {
    vm_provider = "contabo"
    cert_manager_letsencrypt_env = "prod"
  }
)

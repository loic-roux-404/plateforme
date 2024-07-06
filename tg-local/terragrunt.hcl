terraform {
  source = "${include.envcommon.locals.base_source_url}"
}

locals {
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/local.yaml")))
}

inputs = merge(
  local.secret_vars,
  {}
)

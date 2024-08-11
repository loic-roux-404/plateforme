
locals {
  env          = get_env("ENV_NAME", "prod")
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  input_vars   = local.dependencies.dependency.network.outputs
}

locals {  
  env = read_terragrunt_config("env.hcl")
}

remote_state {
  backend = "local"
  config = {
    path = "${get_parent_terragrunt_dir()}/.terragrunt/${local.env.locals.env}/terraform.tfstate"
  }

  generate = {
    path = "backend.tf"
    if_exists = "overwrite"
  }
}

inputs = merge(
  local.env.locals.secret_vars,
  local.env.locals.input_vars
)

locals {  
  env = read_terragrunt_config("env.hcl")
}

remote_state {
  backend = "local"
  config = {
    path = "${get_parent_terragrunt_dir()}/.terragrunt/${local.env.locals.env}/${path_relative_to_include()}/terraform.tfstate"
  }

  generate = {
    path = "backend.tf"
    if_exists = "overwrite"
  }
}

inputs = local.env.locals.input_vars

dependency "network" {
  config_path = find_in_parent_folders("network/${basename(get_original_terragrunt_dir())}")
}

dependency "k3s-core" {
  config_path = find_in_parent_folders("k3s-core/${basename(get_original_terragrunt_dir())}")
}

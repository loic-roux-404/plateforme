dependency "network" {
  config_path = find_in_parent_folders("network/${basename(get_original_terragrunt_dir())}")
}

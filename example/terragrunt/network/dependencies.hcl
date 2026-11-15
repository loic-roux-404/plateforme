dependency "cloud" {
  config_path = find_in_parent_folders("cloud/${basename(get_original_terragrunt_dir())}")
}

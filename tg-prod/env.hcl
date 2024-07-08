locals {
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/prod.yaml")))
  env = "prod"
  input_vars = {
    vm_provider = "contabo"
    cert_manager_letsencrypt_env = local.env
    secrets_file = find_in_parent_folders("secrets/prod.yaml")
    nix_flake = "git+ssh://git@github.com/k3s-paas#default"
  }
}

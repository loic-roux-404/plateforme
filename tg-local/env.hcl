locals {
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/local.yaml")))
  env = "local"
  input_vars = {
    secrets_file = find_in_parent_folders("secrets/local.yaml")
    libvirt_qcow_source = find_in_parent_folders("result/nixos.qcow2")
    nix_flake = "${dirname(find_in_parent_folders("flake.nix"))}#deploy"
  }
}

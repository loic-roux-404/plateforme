locals {
  secret_vars = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets/local.yaml")))
  env = "local"
  input_vars = {
    libvirt_qcow_source = find_in_parent_folders("result/nixos.qcow2")
    arch = get_env("ARCH", "aarch64")
  }
}

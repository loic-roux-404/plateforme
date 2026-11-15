locals {
  env = "local"
  # wrapper root = parent of the dir holding root.hcl (get_parent_terragrunt_dir
  # returns the UNIT dir — see root.hcl note)
  wrapper = dirname(dirname(find_in_parent_folders("root.hcl")))
  input_vars = {
    # built by `paas build` at the wrapper root
    libvirt_qcow_source = "${local.wrapper}/result/nixos.qcow2"
    arch                = get_env("ARCH", "aarch64")
  }
}

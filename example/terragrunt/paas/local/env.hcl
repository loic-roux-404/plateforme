locals {
  env          = "local"
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  wrapper      = dirname(dirname(find_in_parent_folders("root.hcl")))
  secret_vars  = yamldecode(sops_decrypt_file("${local.wrapper}/local.yaml"))
  input_vars = merge(
    # k3s_endpoint / k3s_port / k3s_node_name / k3s_config from the network unit
    local.dependencies.dependency.network.outputs,
    local.secret_vars,
    {
      cert_manager_letsencrypt_env = "local" # pebble issuer + internal-ca CoreDNS wildcard
      # local wrapper has no scratch GitHub org: keep the real org untouched
      enable_github_integration = false
      # object_storage comes from the network layer outputs (host minio via
      # the bridge gateway — usable from terraform AND from longhorn in-VM)
    },
  )
}

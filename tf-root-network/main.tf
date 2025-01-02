locals {
  private_ip_cidrs = [
    "^127\\.", "^10\\.", "^172\\.(1[6-9]|2[0-9]|3[0-1])\\.", "^192\\.168\\."
  ]
  is_private_ip = length([
    for cidr in local.private_ip_cidrs :
    cidr if can(regex(cidr, var.machine.node_ip))
  ]) > 0
}

module "gandi_domain" {
  count            = local.is_private_ip ? 0 : 1
  source           = "../tf-modules-cloud/gandi"
  gandi_token      = var.gandi_token
  paas_base_domain = var.paas_base_domain
  target_ip        = var.machine.node_ip
}

resource "random_password" "admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  keepers = {
    node_id = var.machine.node_id
  }
}

module "deploy" {
  source         = "../tf-modules-nix/deploy"
  node_id        = var.machine.node_id
  node_address   = var.machine.node_ip
  config         = {
    node_hostname = var.machine.node_hostname
    node_ip       = var.machine.node_ip
  }
  nix_flake      = var.nix_flake
  nix_flake_reset = var.nix_flake_reset
  ssh_connection = var.ssh_connection
  nixos_transient_secrets = {
    nodeIp           = var.machine.node_ip
    dexClientId      = "dex-client-id"
    password         = "${random_password.admin_password.bcrypt_hash}"
    paasDomain       = "${var.paas_base_domain}"
  }
}

module "k3s_get_config" {
  source                     = "../tf-modules-cloud/k3s-get-config"
  ssh_connection             = var.ssh_connection
  node_hostname              = module.deploy.config.node_ip
  remote_k3s_config_location = var.remote_k3s_config_location
}

output "password" {
  value     = random_password.admin_password.result
  sensitive = true
}

output "k3s_node_name" {
  value = var.machine.node_hostname
}

output "k3s_endpoint" {
  value     = module.k3s_get_config.k3s_endpoint
  sensitive = true
}

output "k3s_port" {
  value = "6443"
}

output "k3s_config" {
  sensitive = true
  value     = module.k3s_get_config.k3s_config
}

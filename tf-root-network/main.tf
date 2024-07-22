module "gandi_domain" {
  count            = startswith(var.machine.node_ip, "127.") ? 0 : 1
  source           = "../tf-modules-cloud/gandi"
  gandi_token      = var.gandi_token
  paas_base_domain = var.paas_base_domain
  target_ip        = var.machine.node_ip
}

module "tailscale" {
  source                   = "../tf-modules-cloud/tailscale"
  tailscale_trusted_device = var.tailscale_trusted_device
  trusted_ssh_user         = var.ssh_connection.user
  tailscale_tailnet        = var.tailscale_tailnet
  node_hostname            = var.machine.node_hostname
  node_ip                  = var.machine.node_ip
  node_id                  = var.machine.node_id
  tailscale_oauth_client   = var.tailscale_oauth_client
}

resource "random_password" "admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "deploy" {
  source         = "../tf-modules-nix/deploy"
  node_id        = module.tailscale.node_id
  node_address   = module.tailscale.node_address 
  config         = module.tailscale.config
  nix_flake      = var.nix_flake
  ssh_connection = var.ssh_connection
  nixos_transient_secrets = {
    "dexClientId"      = "dex-client-id"
    "tailscaleNodeKey" = "${module.tailscale.config.node_key}"
    "password"         = "${random_password.admin_password.bcrypt_hash}"
    "tailscaleDomain"  = "${module.tailscale.config.node_fqdn}"
    "paasDomain"       = "${var.paas_base_domain}"
  }
}

module "k3s_get_config" {
  source                     = "../tf-modules-cloud/k3s-get-config"
  ssh_connection             = var.ssh_connection
  node_hostname              = module.deploy.config.node_fqdn
  remote_k3s_config_location = "/etc/rancher/k3s/k3s.yaml"
}

output "password" {
  value     = random_password.admin_password.result
  sensitive = true
}

output "k3s_endpoint" {
  value     = "https://${module.k3s_get_config.k3s_endpoint}:6443"
  sensitive = true
}

output "k3s_config" {
  sensitive = true
  value     = module.k3s_get_config.k3s_config
}

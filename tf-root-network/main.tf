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
  node_ip        = module.tailscale.node_ip
  config         = module.tailscale.config
  nix_flake      = var.nix_flake
  dex_client_id  = var.dex_client_id
  ssh_connection = var.ssh_connection
  nixos_transient_secrets = {
    "tailscaleNodeKey"           = "${module.tailscale.config.node_key}"
    "password"                   = "${random_password.admin_password.bcrypt_hash}"
    "tailscaleOauthClientId"     = var.tailscale_oauth_client.id
    "tailscaleOauthClientSecret" = var.tailscale_oauth_client.secret
    "tailscaleNodeHostname"      = module.tailscale.config.node_hostname
  }
}

resource "terraform_data" "wait_tunneled_vm_ssh" {

  connection {
    type    = "ssh"
    user    = var.ssh_connection.user
    host    = module.deploy.config.node_hostname
    timeout = "1m"
  }

  provisioner "remote-exec" {
    on_failure = fail
    inline     = ["echo '${module.deploy.config.node_hostname} => ${module.deploy.config.node_id}'"]
  }
}

output "password" {
  value     = random_password.admin_password.result
  sensitive = true
}

output "tailscale_operator_hostname" {
  value = module.deploy.config.k8s_operator_hostname
}

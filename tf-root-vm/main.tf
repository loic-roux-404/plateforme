module "libvirt_vm" {
  count               = var.vm_provider == "libvirt" ? 1 : 0
  source              = "../tf-modules-cloud/libvirt"
  node_hostname       = "localhost-${count.index}"
  libvirt_qcow_source = var.libvirt_qcow_source
}

module "contabo_vm" {
  source           = "../tf-modules-cloud/contabo"
  count            = var.vm_provider == "contabo" && var.contabo_instance != null ? 1 : 0
  contabo_instance = var.contabo_instance
  image_version    = var.image_version
  image_url_format = var.image_url_format
  ssh_connection   = var.ssh_connection
  node_hostname    = "k3s-paas-master-${count.index}"
}

locals {
  contabo_hosts = { for count, vm in module.contabo_vm : count => {
    node_hostname = vm.node_hostname
    node_id = vm.node_id
    node_ip = vm.node_ip
  } }
  libvirt_hosts = { for count, vm in module.libvirt_vm : count => {
    node_hostname = vm.node_hostname
    node_id = vm.node_id
    node_ip = vm.node_ip
  } }
  machines_hosts = merge(
    local.libvirt_hosts,
    local.contabo_hosts
  )
}

module "gandi_domain" {
  source           = "../tf-modules-cloud/gandi"
  for_each         = local.contabo_hosts
  gandi_token      = var.gandi_token
  paas_base_domain = var.paas_base_domain
  target_ip        = each.value.node_ip
}

module "tailscale" {
  for_each                 = local.machines_hosts
  source                   = "../tf-modules-cloud/tailscale"
  tailscale_trusted_device = var.tailscale_trusted_device
  trusted_ssh_user         = var.ssh_connection.user
  tailscale_tailnet        = var.tailscale_tailnet
  node_hostname            = each.value.node_hostname
  node_ip                  = each.value.node_ip
  node_id                  = each.value.node_id
  tailscale_oauth_client   = var.tailscale_oauth_client
}

resource "random_password" "admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "deploy" {
  source         = "../tf-modules-nix/deploy"
  for_each       = module.tailscale
  node_id        = each.value.node_id
  node_ip        = each.value.node_ip
  config         = each.value.config
  nix_flake      = var.nix_flake
  secrets_file   = var.secrets_file
  dex_client_id  = var.dex_client_id
  ssh_connection = var.ssh_connection
  nixos_transient_secrets = {
    "tailscaleNodeKey"           = "${each.value.config.node_key}"
    "password"                   = "${random_password.admin_password.bcrypt_hash}"
    "tailscaleOauthClientId"     = var.tailscale_oauth_client.id
    "tailscaleOauthClientSecret" = var.tailscale_oauth_client.secret
    "tailscaleNodeHostname"      = each.value.config.node_hostname
  }
}

resource "terraform_data" "wait_tunneled_vm_ssh" {
  for_each = module.deploy

  connection {
    type    = "ssh"
    user    = var.ssh_connection.user
    host    = each.value.config.node_hostname
    timeout = "1m"
  }

  provisioner "remote-exec" {
    on_failure = fail
    inline     = ["echo '${each.value.config.node_hostname} => ${each.value.config.node_id}'"]
  }
}

output "password" {
  value     = random_password.admin_password.result
  sensitive = true
}

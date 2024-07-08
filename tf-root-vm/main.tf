module "libvirt_vm" {
  count         = var.vm_provider == "libvirt" ? 1 : 0
  source        = "../tf-modules-cloud/libvirt"
  node_hostname = "localhost"
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
  contabo_hosts = { for vm in module.contabo_vm : vm.name => {
    id = vm.id
    ip = vm.ip
    }
  }
  machines_hosts = merge(
    { for vm in module.libvirt_vm : vm.name => {
      id = vm.id
      ip = vm.ip
      }
    },
    local.contabo_hosts
  )
}

module "gandi_domain" {
  source           = "../tf-modules-cloud/gandi"
  for_each         = local.contabo_hosts
  gandi_token      = var.gandi_token
  paas_base_domain = var.paas_base_domain
  target_ip        = each.value.ip
}

locals {
  ssh_connection = merge(var.ssh_connection, {
    public_key  = trimspace(file(pathexpand(var.ssh_connection.public_key)))
    private_key = trimspace(file(pathexpand(var.ssh_connection.private_key)))
  })
}

module "tailscale" {
  source                   = "../tf-modules-cloud/tailscale"
  tailscale_trusted_device = var.tailscale_trusted_device
  trusted_ssh_user         = var.ssh_connection.user
  tailscale_tailnet        = var.tailscale_tailnet
}

resource "random_password" "admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "deploy" {
  source         = "../tf-modules-nix/deploy"
  for_each       = local.machines_hosts
  node_hostname  = each.key
  nix_flake = var.nix_flake
  secrets_file = var.secrets_file
  dex_client_id  = var.dex_client_id
  vm_ip          = each.value.ip
  ssh_connection = local.ssh_connection
  nixos_options = {
    "networking.hostName" = each.key
  }
  nixos_transient_secrets = {
    "tailscale"                     = "${module.tailscale.key}"
    "password"                      = "${random_password.admin_password.bcrypt_hash}"
    "tailscale_oauth_client_id"     = var.tailscale_oauth_client.id
    "tailscale_oauth_client_secret" = var.tailscale_oauth_client.secret
  }
}

resource "terraform_data" "wait_tunneled_vm_ssh" {
  for_each = module.deploy

  connection {
    type        = "ssh"
    user        = local.ssh_connection.user
    private_key = local.ssh_connection.private_key
    host        = each.value.hostname
  }

  provisioner "remote-exec" {
    on_failure = fail
    inline     = ["echo ${each.value.hostname}"]
  }
}

data "healthcheck_http" "k3s" {
  path         = "livez?verbose"
  status_codes = [200]
  endpoints = [for _, v in module.deploy : {
    name    = v.hostname
    address = v.hostname
    port    = 6443
  }]
}

data "healthcheck_filter" "k3s" {
  up   = data.healthcheck_http.k3s.up
  down = data.healthcheck_http.k3s.down
}

output "up_k3s_endpoint" {
  value = data.healthcheck_filter.k3s.up
}

output "password" {
  value     = random_password.admin_password.result
  sensitive = true
}

data "tailscale_device" "trusted_device" {
  for_each = toset([var.tailscale_trusted_device])
  name     = each.value
  wait_for = "60s"
}

resource "tailscale_device_authorization" "sample_authorization" {
  for_each   = data.tailscale_device.trusted_device
  device_id  = each.value.id
  authorized = true
}

resource "tailscale_acl" "as_json" {
  acl = jsonencode({
    acls = [
      {
        action = "accept"
        src    = ["*"]
        dst    = ["*:*"]
      }
    ]
    ssh = [
      {
        action = "accept"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self"]
        users  = [var.trusted_ssh_user]
      }
    ],
    nodeAttrs = [
      {
        target = ["autogroup:member"]
        attr   = ["funnel"]
      },
    ],
    tagOwners = {
      "tag:k8s-operator" = []
      "tag:k8s"          = ["tag:k8s-operator"]
    }
    grants = [{
      src = ["autogroup:member"]
      dst = ["tag:k8s-operator"]
      app = {
        "tailscale.com/cap/kubernetes" = [{
          impersonate = {
            groups = ["system:masters"]
          }
        }]
      }
    }]
  })
}

resource "tailscale_dns_preferences" "sample_preferences" {
  magic_dns = true
}

resource "tailscale_tailnet_key" "k3s_paas_node" {
  reusable      = true
  ephemeral     = true
  preauthorized = true
  expiry        = 3600
  description   = "VM instance key"
}

data "gandi_domain" "k3s_domain" {
  name = var.paas_base_domain
}

resource "gandi_dnssec_key" "dnssec" {
  algorithm  = 13
  domain     = data.gandi_domain.k3s_domain.id
  type       = "zsk"
  public_key = var.gandi_dnssec_public_key
}

resource "gandi_livedns_record" "www" {
  for_each = toset(["@", "*"])
  zone     = data.gandi_domain.k3s_domain.id
  name     = each.key
  type     = "A"
  ttl      = 3600
  values = [
    data.contabo_instance.k3s_paas_master.ip_config[0].v4[0].ip
  ]
}

locals {
  ssh_connection = merge(var.ssh_connection, {
    public_key  = trimspace(file(pathexpand(var.ssh_connection.public_key)))
    private_key = trimspace(file(pathexpand(var.ssh_connection.private_key)))
  })
}

resource "contabo_secret" "k3s_paas_master_trusted_key" {
  name  = "k3s_paas_master_trusted_key"
  type  = "ssh"
  value = local.ssh_connection.public_key
}

resource "contabo_image" "k3s_paas_master_image" {
  name        = "k3s"
  image_url   = format(var.image_url_format, var.image_version)
  os_type     = "Linux"
  version     = var.image_version
  description = "Generated PaaS vm image with packer"
}

data "contabo_instance" "k3s_paas_master" {
  id = var.contabo_instance
}

resource "contabo_instance" "k3s_paas_master" {
  existing_instance_id = var.contabo_instance
  display_name         = "nixos-k3s-paas"
  image_id             = contabo_image.k3s_paas_master_image.id
  ssh_keys             = [contabo_secret.k3s_paas_master_trusted_key.id]
}

locals {
  nixos_options = {
    "k3s-paas.dex.dexClientId" = "id-dex-default"
    "k3s-paas.tailscale.authKey" = tailscale_tailnet_key.k3s_paas_node.key
  }
  nixos_option_flag = join(" ", [for k, v in local.nixos_options : "--nixos-option ${k}=${v}"])
}

resource "terraform_data" "colemna_apply" {
  provisioner "local-exec" {
    on_failure = fail
    command    = "colmena apply ${nixos_option_flag} --on master"
  }
}

resource "terraform_data" "tailscale_bootstrap" {
  triggers_replace = [
    contabo_instance.k3s_paas_master.id
  ]

  connection {
    type        = "ssh"
    user        = local.ssh_connection.user
    private_key = local.ssh_connection.private_key
    host        = contabo_instance.k3s_paas_master.ip_config[0].v4[0].ip
  }

  provisioner "remote-exec" {
    on_failure = fail
    inline = [
      "echo ${contabo_instance.k3s_paas_master.id}",
    ]
  }
}

resource "null_resource" "copy_k3s_config" {
  triggers = {
    instance_id = contabo_instance.k3s_paas_master.id
    started_id  = terraform_data.tailscale_bootstrap.id
  }
  provisioner "local-exec" {
    command = "ssh ${var.ssh_connection.user}@k3s-paas-master -p 2222 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config"
  }
}

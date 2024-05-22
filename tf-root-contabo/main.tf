data "tailscale_device" "trusted_device" {
  name     = var.tailscale_trusted_device
  wait_for = "60s"
}

resource "tailscale_acl" "as_json" {
  acl = jsonencode({
    acls = [
      {
        action : "accept",
        src : ["*"],
        dst : ["*:*"]
      },
    ]
    ssh = [
      {
        action = "accept"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self"]
        users  = [var.trusted_ssh_user]
      }
    ]
  })
}

resource "tailscale_tailnet_key" "k3s_paas_node" {
  reusable      = true
  ephemeral     = false
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
    data.contabo_instance.paas_instance.ip_config[0].v4[0].ip
  ]
}

locals {
  ssh_connection = merge(var.ssh_connection, {
    public_key  = trimspace(file(pathexpand(var.ssh_connection.public_key)))
    private_key = trimspace(file(pathexpand(var.ssh_connection.private_key)))
  })
}

resource "contabo_secret" "paas_instance_ssh_key" {
  name  = "paas_instance_ssh_key"
  type  = "ssh"
  value = local.ssh_connection.public_key
}

resource "contabo_secret" "paas_instance_password" {
  name  = "paas_instance_password"
  type  = "password"
  value = local.ssh_connection.password
}

resource "contabo_image" "paas_instance_qcow2" {
  name        = "k3s"
  image_url   = var.image_url
  os_type     = "Linux"
  version     = var.image_version
  description = "Generated PaaS vm image with packer"
}

data "contabo_instance" "paas_instance" {
  id = var.contabo_instance
}

resource "contabo_instance" "paas_instance" {
  existing_instance_id = var.contabo_instance
  display_name         = "nixos-k3s-paas"
  image_id             = contabo_image.paas_instance_qcow2.id
  ssh_keys             = [contabo_secret.paas_instance_ssh_key.id]
  user_data = sensitive(templatefile(
    "${path.root}/user-data.yaml.tmpl",
    {
      tailscale_key = tailscale_tailnet_key.k3s_paas_node.key
    }
  ))
}

resource "terraform_data" "paas_instance_wait_bootstrap" {
  triggers_replace = [
    contabo_instance.paas_instance.id
  ]

  connection {
    type        = "ssh"
    user        = local.ssh_connection.user
    private_key = local.ssh_connection.private_key
    host        = contabo_instance.paas_instance.ip_config[0].v4[0].ip
  }

  provisioner "remote-exec" {
    on_failure = fail
    inline = [
      "sudo cloud-init status --wait && sudo cloud-init clean"
    ]
  }
}

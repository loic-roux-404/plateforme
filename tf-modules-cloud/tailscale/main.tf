data "tailscale_devices" "already_present" {
  name_prefix = var.node_hostname
}

locals {
  already_present = length(data.tailscale_devices.already_present.devices) > 0
  node_fqdn       = "${var.node_hostname}.${var.tailscale_tailnet}"
}

data "tailscale_device" "trusted_device" {
  for_each = toset([var.tailscale_trusted_device])
  name     = "${each.value}.${var.tailscale_tailnet}"
  wait_for = "60s"
}

resource "tailscale_device_authorization" "sample_authorization" {
  for_each   = data.tailscale_device.trusted_device
  device_id  = each.value.id
  authorized = true
}

resource "tailscale_acl" "as_json" {
  overwrite_existing_content = true
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
        action : "accept",
        src : ["autogroup:member"],
        dst : ["autogroup:self"],
        users : ["autogroup:nonroot"]
      },
      {
        action : "accept",
        src : ["tag:all", "autogroup:member"],
        dst : ["tag:all"],
        users : ["autogroup:nonroot"]
      }
    ],
    nodeAttrs = [
      {
        target = ["autogroup:member"]
        attr   = ["funnel"]
      },
    ],
    tagOwners = {
      "tag:all" : [],
    }
    "autoApprovers" : {
      "routes" : {
        "100.64.0.0/10" : ["tag:all"],
        "2002:6440:0000::/48": ["tag:all"]
      },
    }
  })
}

resource "tailscale_dns_preferences" "sample_preferences" {
  magic_dns = true
}

resource "tailscale_tailnet_key" "k3s_paas_node" {
  depends_on          = [tailscale_acl.as_json]
  reusable            = true
  ephemeral           = false
  recreate_if_invalid = "always"
  preauthorized       = true
  description         = "key-with-already-present-is-${tostring(local.already_present)}"
  tags                = ["tag:all"]
}

output "node_id" {
  value = var.node_id
}

output "node_address" {
  value = local.already_present ? flatten([
    for device in data.tailscale_devices.already_present.devices: device.addresses
  ])[0] : var.node_ip
}

output "config" {
  depends_on = [tailscale_tailnet_key.k3s_paas_node]
  value = {
    node_ip               = var.node_ip
    node_hostname         = var.node_hostname
    node_fqdn             = local.node_fqdn
    node_key              = tailscale_tailnet_key.k3s_paas_node.key
  }
}

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
        dst : ["tag:all", "tag:k8s-operator"],
        users : ["autogroup:nonroot"]
      },
      {
        action : "accept",
        src : ["autogroup:member"],
        dst : ["tag:k8s-operator"],
        users : ["autogroup:nonroot"]
      },
    ],
    nodeAttrs = [
      {
        target = ["autogroup:member"]
        attr   = ["funnel"]
      },
    ],
    tagOwners = {
      "tag:all" : [],
      "tag:k8s-operator" = []
      "tag:k8s"          = ["tag:k8s-operator"]
    }
    grants = [{
      src = ["tag:all"]
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

resource "terraform_data" "node_changed" {
  triggers_replace = [var.node_id]
}

resource "tailscale_tailnet_key" "k3s_paas_node" {
  depends_on          = [tailscale_acl.as_json]
  reusable            = true
  ephemeral           = false
  expiry              = 3600
  recreate_if_invalid = "always"
  preauthorized       = true
  description         = "VM instance key"
  tags                = ["tag:all"]
}

resource "terraform_data" "destroy_node" {
  input = {
    TAILNET             = var.tailscale_tailnet
    OAUTH_CLIENT_ID     = var.tailscale_oauth_client.id
    OAUTH_CLIENT_SECRET = var.tailscale_oauth_client.secret
    NODE_HOSTNAMES = join(",", [
      var.node_hostname,
      "k8s-operator-${var.node_hostname}"
    ])
  }

  provisioner "local-exec" {
    when        = destroy
    environment = self.input
    on_failure  = fail
    command     = "${path.module}/delete-node-devices.sh"
  }
}

data "tailscale_devices" "already_present" {
  name_prefix = var.node_hostname
}

locals  {
  already_present = length(data.tailscale_devices.already_present.devices) > 0
  node_fqdn = "${var.node_hostname}.${var.tailscale_tailnet}"
}

output "node_id" {
  value = var.node_id
}

output "node_address" {
  value = local.already_present ? local.node_fqdn : var.node_ip
}

output "config" {
  depends_on = [tailscale_tailnet_key.k3s_paas_node]
  value = {
    node_ip               = var.node_ip
    node_hostname         = var.node_hostname
    node_fqdn             = local.node_fqdn
    node_key              = tailscale_tailnet_key.k3s_paas_node.key
    k8s_operator_hostname = "k8s-operator-${var.node_hostname}"
  }
}

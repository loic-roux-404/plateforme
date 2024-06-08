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
        src    = ["tag:all", "*"]
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
      "tag:all": [],
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
  tags = ["tag:all"]
}

output "key" {
  value = tailscale_tailnet_key.k3s_paas_node.key
}

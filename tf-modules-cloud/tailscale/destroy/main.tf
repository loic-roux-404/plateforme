resource "terraform_data" "destroy_node" {
  input = {
    TAILNET             = var.tailscale_tailnet
    OAUTH_CLIENT_ID     = var.tailscale_oauth_client.id
    OAUTH_CLIENT_SECRET = var.tailscale_oauth_client.secret
    NODE_HOSTNAMES = join(",", [
      var.node_hostname
    ])
  }

  provisioner "local-exec" {
    when        = destroy
    environment = self.input
    on_failure  = fail
    command     = "${path.module}/delete-node-devices.sh"
  }

  lifecycle {
    create_before_destroy = true
  }
}

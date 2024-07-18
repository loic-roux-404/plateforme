resource "terraform_data" "wait_ssh" {
  connection {
    type    = "ssh"
    user    = var.ssh_connection.user
    host    = var.node_hostname
    timeout = "1m"
  }

  provisioner "remote-exec" {
    on_failure = fail
    inline     = ["echo '${var.node_hostname}'"]
  }
}

data "external" "k3s_config" {
  depends_on = [ terraform_data.wait_ssh ]
  program = ["${path.module}/fetch-config.sh"]
  query = {
    user   = var.ssh_connection.user
    host = var.node_hostname
    location = var.remote_k3s_config_location
  }
}

locals {
  kube_config = yamldecode(data.external.k3s_config.result.config)
  cluster = one([ for each in toset(local.kube_config.clusters) : 
      each.cluster if each.name == var.context_cluster_name
  ])
  user = one([for each in toset(local.kube_config.users) : 
    each.user if each.name == var.context_user_name
  ])
}

output "k3s_endpoint" {
  value = var.node_hostname
}

output "kube_config" {
  value = local.cluster
}

output "k3s_config" {
  sensitive = true
  value = {
    cluster_ca_certificate = base64decode(local.cluster["certificate-authority-data"])
    client_certificate = base64decode(local.user.client-certificate-data)
    client_key = base64decode(local.user.client-key-data)
  }
}

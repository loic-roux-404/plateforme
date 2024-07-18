resource "contabo_secret" "k3s_paas_master_trusted_key" {
  name  = "k3s_paas_master_trusted_key"
  type  = "ssh"
  value = file(var.ssh_connection.public_key)
}

resource "contabo_image" "k3s_paas_master_image" {
  name        = "nixos-k3s-paas-${var.image_version}"
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
  display_name         = var.node_hostname
  image_id             = contabo_image.k3s_paas_master_image.id
  ssh_keys             = [contabo_secret.k3s_paas_master_trusted_key.id]

  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.ip_config[0].v4[0].ip}"
  }
}

output "node_hostname" {
  depends_on = [contabo_instance.k3s_paas_master]
  value      = var.node_hostname
}

output "node_ip" {
  value = data.contabo_instance.k3s_paas_master.ip_config[0].v4[0].ip
}

output "node_id" {
  value = contabo_instance.k3s_paas_master.id
}

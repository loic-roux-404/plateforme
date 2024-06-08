resource "terraform_data" "apply_hostname" {
  connection {
    type        = "ssh"
    user        = var.ssh_connection.user
    private_key = var.ssh_connection.private_key
    host        = var.vm_ip
  }

  provisioner "file" {
    content = var.node_hostname
    destination = "hostname"
  }
}

resource "terraform_data" "apply_secrets" {
  for_each = var.nixos_secrets
  connection {
    type        = "ssh"
    user        = var.ssh_connection.user
    private_key = var.ssh_connection.private_key
    host        = var.vm_ip
  }

  provisioner "file" {
    content = each.value
    destination = ".${each.key}"
  }
}


module "deploy_nixos" {
  source     = "github.com/Gabriella439/terraform-nixos-ng//nixos"
  host       = "${var.ssh_connection.user}@${var.vm_ip}"
  flake      = var.nix_flake
  arguments  = ["--use-remote-sudo"]
  depends_on = [terraform_data.apply_hostname, terraform_data.apply_secrets]
}

output "secure_hostname" {
  depends_on = [module.deploy_nixos]
  value      = var.node_hostname
}

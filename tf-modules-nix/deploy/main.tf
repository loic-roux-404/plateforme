data "external" "deploy_key" {
  program = ["bash", "${path.module}/key-to-age.sh"]

  query = {
    key  = pathexpand(var.ssh_connection.private_key)
    args = "-private-key"
  }
}

resource "terraform_data" "check_ssh" {
  connection {
    type        = "ssh"
    user        = var.ssh_connection.user
    private_key = file(pathexpand(var.ssh_connection.private_key))
    host        = var.node_ip
    timeout = "1m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'SSH connection established'",
    ]
  }
}

data "external" "machine_key_pub" {
  depends_on = [terraform_data.check_ssh]
  program    = ["bash", "${path.module}/retrieve-vm-age-key.sh"]

  query = {
    machine_ip = var.node_ip
  }
}

resource "local_sensitive_file" "non_encrypted_secrets" {
  content  = yamlencode(var.nixos_transient_secrets)
  filename = "${path.cwd}/${var.node_ip}.yaml"
}

resource "terraform_data" "create_transient_secrets" {
  triggers_replace = {
    changed = var.node_id
  }
  provisioner "local-exec" {
    environment = {
      SOPS_AGE_KEY        = data.external.deploy_key.result.key
      SOPS_AGE_RECIPIENTS = data.external.machine_key_pub.result.key
    }
    interpreter = [ "sops", "--encrypt", "--in-place"]
    command = local_sensitive_file.non_encrypted_secrets.filename
  }
}

data "local_file" "encrypted_secrets" {
  depends_on = [terraform_data.create_transient_secrets]
  filename   = local_sensitive_file.non_encrypted_secrets.filename
}

resource "terraform_data" "apply_secrets" {
  triggers_replace = {
    changed = data.local_file.encrypted_secrets.content
  }
  connection {
    type        = "ssh"
    user        = var.ssh_connection.user
    private_key = file(pathexpand(var.ssh_connection.private_key))
    host        = var.node_ip
  }

  provisioner "file" {
    content     = data.local_file.encrypted_secrets.content
    destination = "/home/${var.ssh_connection.user}/secrets.yaml"
  }
}

locals {
  components     = split("#", var.nix_flake)
  uri            = local.components[0]
  attribute_path = local.components[1]
  real_flake     = "${local.uri}#nixosConfigurations.${local.attribute_path}"
}

data "external" "instantiate" {
  depends_on = [terraform_data.apply_secrets]
  program    = ["${path.module}/instantiate.sh", local.real_flake]
}

resource "terraform_data" "deploy" {
  triggers_replace = {
    derivation = data.external.instantiate.result["path"]
    secrets = data.local_file.encrypted_secrets.content
  }

  provisioner "local-exec" {
    environment = { NIX_SSHOPTS = var.nix_ssh_options }
    interpreter = concat(
      [
        "nixos-rebuild", 
        "--fast",
        "--flake", var.nix_flake,
        "--target-host", "${var.ssh_connection.user}@${var.node_ip}"
      ],
      var.nix_rebuild_arguments
    )

    command = "switch"
  }
}

output "config" {
  depends_on = [terraform_data.deploy]
  value      = merge(var.config, {
    node_ip = var.node_ip
    node_id = var.node_id
  })
}

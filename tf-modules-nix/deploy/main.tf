data "external" "deploy_key" {
  program = ["bash", "${path.module}/key-to-age.sh"]

  query = {
    key  = var.ssh_connection.private_key
    args = "-private-key"
  }
}

resource "terraform_data" "check_ssh" {
  connection {
    type        = "ssh"
    user        = var.ssh_connection.user
    private_key = var.ssh_connection.private_key
    host        = var.vm_ip
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
    machine_ip = var.vm_ip
  }
}

locals {
  sops_environment = {
    SOPS_AGE_KEY        = data.external.deploy_key.result.key
    SOPS_AGE_RECIPIENTS = data.external.machine_key_pub.result.key
  }
}

resource "local_sensitive_file" "non_encrypted_secrets" {
  content  = yamlencode(var.nixos_transient_secrets)
  filename = "${path.cwd}/${uuid()}.yaml"
}

resource "terraform_data" "create_transient_secrets" {
  triggers_replace = {
    always = timestamp()
  }
  provisioner "local-exec" {
    environment = local.sops_environment
    interpreter = [
      "sops", "--encrypt", "--in-place",
    ]
    command = local_sensitive_file.non_encrypted_secrets.filename
  }
}

data "local_file" "encrypted_secrets" {
  depends_on = [terraform_data.create_transient_secrets]
  filename   = local_sensitive_file.non_encrypted_secrets.filename
}

resource "terraform_data" "apply_secrets" {
  triggers_replace = {
    always = timestamp()
  }
  connection {
    type        = "ssh"
    user        = var.ssh_connection.user
    private_key = var.ssh_connection.private_key
    host        = var.vm_ip
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
  }

  provisioner "local-exec" {
    environment = { NIX_SSHOPTS = var.nix_ssh_options }
    interpreter = concat(
      [
        "nixos-rebuild",
        "--fast",
        "--flake", var.nix_flake,
        "--target-host",
        "${var.ssh_connection.user}@${var.vm_ip}"
      ],
      var.nix_rebuild_arguments
    )

    command = "switch"
  }
}

resource "terraform_data" "delete_transient_secrets" {
  triggers_replace = {
    after = terraform_data.deploy
  }
  provisioner "local-exec" {
    interpreter = ["rm", "-f"]
    command = local_sensitive_file.non_encrypted_secrets.filename
  }
}


output "hostname" {
  depends_on = [terraform_data.deploy]
  value      = var.node_hostname
}

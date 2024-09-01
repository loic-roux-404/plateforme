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
    host        = var.node_address
    timeout     = "1m"
  }

  provisioner "remote-exec" {
    inline = ["echo 'SSH connection ready'", ]
  }
}

data "external" "machine_key_pub" {
  depends_on = [terraform_data.check_ssh]
  program    = ["bash", "${path.module}/retrieve-vm-age-key.sh"]

  query = {
    machine_ip = var.node_address
  }
}

resource "tls_private_key" "machine_key" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "secured_machine_key" {
  content  = tls_private_key.machine_key.public_key_openssh
  filename = "${path.cwd}/${var.node_address}.pub"
}

data "external" "secured_machine_key_pub" {
  depends_on = [terraform_data.check_ssh]
  program    = ["bash", "${path.module}/key-to-age.sh"]

  query = {
    key  = pathexpand(local_sensitive_file.secured_machine_key.filename)
  }
}

resource "local_sensitive_file" "non_encrypted_secrets" {
  content  = yamlencode(merge(var.nixos_transient_secrets, {
    nodePrivateKey = tls_private_key.machine_key.private_key_openssh
  }))
  filename = "${path.cwd}/${var.node_address}.yaml"
}

locals {
  all_recipients = [
    data.external.machine_key_pub.result.key,
    data.external.secured_machine_key_pub.result.key
  ]
}

resource "terraform_data" "create_transient_secrets" {
  triggers_replace = {
    changed_secrets = local_sensitive_file.non_encrypted_secrets
  }
  provisioner "local-exec" {
    environment = {
      SOPS_AGE_KEY        = data.external.deploy_key.result.key
      SOPS_AGE_RECIPIENTS = join(",", [for each in local.all_recipients : each if each != ""])
    }
    interpreter = ["sops", "--encrypt", "--in-place"]
    command     = local_sensitive_file.non_encrypted_secrets.filename
  }
}

data "local_sensitive_file" "encrypted_secrets" {
  depends_on = [terraform_data.create_transient_secrets]
  filename   = local_sensitive_file.non_encrypted_secrets.filename
}

resource "terraform_data" "upload_secrets" {
  triggers_replace = {
    changed_secrets = data.local_sensitive_file.encrypted_secrets.content
    changed_node    = var.node_id
  }
  connection {
    type        = "ssh"
    user        = var.ssh_connection.user
    private_key = file(pathexpand(var.ssh_connection.private_key))
    host        = var.node_address
  }

  provisioner "file" {
    content     = data.local_sensitive_file.encrypted_secrets.content
    destination = "/home/${var.ssh_connection.user}/secrets.yaml"
  }
}

locals {
  components     = split("#", var.nix_flake)
  uri            = local.components[0]
  attribute_path = local.components[1]
  real_flake     = "${local.uri}#nixosConfigurations.${local.attribute_path}"
  nix_rebuild_interpreter = concat(
    [
      "nixos-rebuild",
      "--fast",
      "--build-host", "${var.ssh_connection.user}@${var.node_address}",
      "--target-host", "${var.ssh_connection.user}@${var.node_address}"
    ],
    var.nix_rebuild_arguments
  )
}

data "external" "instantiate" {
  depends_on = [terraform_data.upload_secrets]
  program    = ["${path.module}/instantiate.sh", local.real_flake]
}

resource "terraform_data" "deploy" {
  triggers_replace = {
    derivation = data.external.instantiate.result["path"]
  }

  provisioner "local-exec" {
    interpreter = concat(local.nix_rebuild_interpreter, ["--flake", var.nix_flake])
    environment = { NIX_SSHOPTS = var.nix_ssh_options }
    command = "switch"
  }
}

resource "terraform_data" "reset" {
  count = var.nix_flake_reset != null ? 1 : 0
  input = {
    nix_flake_reset = var.nix_flake_reset
    nix_rebuild_interpreter = local.nix_rebuild_interpreter
    nix_ssh_options = var.nix_ssh_options
  }

  provisioner "local-exec" {
    when = destroy
    on_failure = continue
    interpreter = concat(
      self.input.nix_rebuild_interpreter, 
      ["--flake", self.input.nix_flake_reset]
    )
    environment = { NIX_SSHOPTS = self.input.nix_ssh_options }
    command = "switch"
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "config" {
  depends_on = [terraform_data.deploy]
  value = merge(var.config, {
    node_address = var.node_address
    node_id = var.node_id
  })
}

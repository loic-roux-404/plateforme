data "external" "deploy_key_pub" {
  program = ["bash", "${path.module}/key-to-age.sh"]

  query = {
    key = var.ssh_connection.public_key
  }
}

data "external" "deploy_key" {
  program = ["bash", "${path.module}/key-to-age.sh"]

  query = {
    key = var.ssh_connection.private_key
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
  depends_on = [ terraform_data.check_ssh ]
  program = ["bash", "${path.module}/retrieve-vm-age-key.sh"]

  query = {
    machine_ip = var.vm_ip
  }
}

locals {
  keys = [
    data.external.deploy_key_pub.result.key,
    data.external.machine_key_pub.result.key
  ]
  file_content = yamlencode({
    keys = local.keys
    creation_rules = [
      {
        path_regex = "\\w\\.(yaml|json|env|ini)$"
        key_groups = [
          {
            age = local.keys
          }
        ]
      }
    ]
  })
}

resource "local_file" "sops_config" {
  content  = local.file_content
  filename = "${path.cwd}/.sops.yaml"
}

resource "local_sensitive_file" "non_encrypted_secrets" {
  content  = yamlencode(var.nixos_secrets)
  filename = "${path.cwd}/secrets.yaml"
}

resource "terraform_data" "create_secrets" {
  triggers_replace = {
    always = timestamp()
  }
  provisioner "local-exec" {
    environment = {
      SOPS_AGE_KEY = data.external.deploy_key.result.key
    }
    interpreter = [
      "sops", "--config", local_file.sops_config.filename, "--encrypt", "--in-place",
    ]
    command = local_sensitive_file.non_encrypted_secrets.filename
  }
}

data "local_file" "encrypted_secrets" {
  depends_on = [terraform_data.create_secrets]
  filename = "${path.cwd}/secrets.yaml"
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
    content = data.local_file.encrypted_secrets.content
    destination = "/home/${var.ssh_connection.user}/secrets.yaml"
  }
}

locals {
  components = split("#", var.nix_flake)
  uri = local.components[0]
  attribute_path = local.components[1]
  real_flake = "${local.uri}#nixosConfigurations.${local.attribute_path}"
}

resource local_file "additional_nixos_vars" {
  filename = "${path.cwd}/nixos/temporary-configuration.nix"
  content  = templatefile("${path.module}/temporary-configuration.nix.tftpl", {
    nixos_options = var.nixos_options
  })

  provisioner "local-exec" {
    command = "git update-index --assume-unchanged ${local_file.additional_nixos_vars.filename}"
  }

  provisioner "local-exec" {
    when = "destroy"
    command = "git update-index --skip-worktree  ${local_file.additional_nixos_vars.filename}"
  }
}

data "external" "instantiate" {
  depends_on = [terraform_data.apply_secrets, local_file.additional_nixos_vars]
  program = [ "${path.module}/instantiate.sh", local.real_flake]
}

resource "null_resource" "deploy" {
  triggers = {
    derivation = data.external.instantiate.result["path"]
  }

  provisioner "local-exec" {
    environment = {
      NIX_SSHOPTS = var.nix_ssh_options
    }

    interpreter = concat (
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

resource "terraform_data" "reset_tmp_config" {
  depends_on = [ null_resource.deploy ]
  provisioner "local-exec" {
    command = "echo '{...}: {}' > ${local_file.additional_nixos_vars.filename}"
  }
}

output "hostname" {
  depends_on = [null_resource.deploy]
  value      = var.node_hostname
}

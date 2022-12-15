variable "client_id" {
  type    = string
  default = ""
}

variable "client_cert_path" {
  type    = string
  default = ""
}

variable "tenant_id" {
  type    = string
  default = ""
}

variable "subscription_id" {
  type    = string
  default = ""
}

variable "resource_group_name" {
  type    = string
  default = "kubeapps-group"
}

variable "image_sku" {
  type    = string
  default = "20_04-daily-lts-gen2"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "ansible_password_file" {
  type    = string
  default = ""
}

variable "ansible_group_vars" {
  type    = string
  default = "prod"
}

source "azure-arm" "vm" {
  subscription_id  = var.subscription_id
  client_id        = var.client_id
  client_cert_path = var.client_cert_path
  tenant_id        = var.tenant_id

  managed_image_name                = "kubeapps-az-arm"
  managed_image_resource_group_name = var.resource_group_name
  build_resource_group_name         = var.resource_group_name
  os_type                           = "Linux"
  image_publisher                   = "Canonical"
  image_offer                       = "0001-com-ubuntu-server-focal-daily"
  image_sku                         = var.image_sku

  vm_size      = var.vm_size
  communicator = "ssh"
}

build {

  sources = ["sources.azure-arm.vm"]

  provisioner "file" {
    source      = "../playbook/requirements.txt"
    destination = "requirements.txt"
  }

  provisioner "shell" {
    inline = [
      "curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py",
      "sudo python3 /tmp/get-pip.py",
      "sudo pip3 install --ignore-installed ansible==6.5.0 pyyaml openshift kubernetes"
    ]
  }

  provisioner "file" {
    source      = var.ansible_password_file
    destination = "/tmp/.vault"
  }

  provisioner "ansible-local" {
    command                 = "sudo ansible-playbook"
    playbook_file           = "../playbook/site.yaml"
    playbook_dir            = "../playbook/"
    group_vars              = "../playbook/inventories/${var.ansible_group_vars}/group_vars"
    extra_arguments         = [
      "--vault-password-file /tmp/.vault",
      "--skip-tags kubeapps"
    ]
    galaxy_file             = "../playbook/requirements.yaml"
    galaxy_command          = "sudo ansible-galaxy"
    galaxy_roles_path       = "/usr/share/ansible/roles"
    galaxy_collections_path = "/usr/share/ansible/collections"
    staging_directory       = "/tmp/packer-provisioner-ansible-local"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}

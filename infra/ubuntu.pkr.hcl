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

source "azure-arm" "vm" {
  use_azure_cli_auth = true

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
      "sudo apt update && sudo apt upgrade -y",
      "curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py",
      "sudo python3 /tmp/get-pip.py",
      "sudo pip3 install --ignore-installed ansible==6.5.0 pyyaml openshift kubernetes",
      "sudo mkdir /playbook && sudo chown -R packer:packer /playbook",
    ]
  }

  provisioner "ansible-local" {
    command       = "sudo ansible-playbook"
    playbook_file = "../playbook/site.yaml"
    playbook_dir  = "../playbook/"
    extra_arguments = ["--skip-tags kubeapps"]
    galaxy_file             = "../playbook/requirements.yaml"
    galaxy_command          = "sudo ansible-galaxy"
    galaxy_roles_path       = "/usr/share/ansible/roles"
    galaxy_collections_path = "/usr/share/ansible/collections"
    staging_directory       = "/playbook/"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "sudo apt autoremove"
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}

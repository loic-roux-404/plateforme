variable "accelerator" {
  type    = string
  default = "kvm"
}

variable "cpus" {
  type    = string
  default = "4"
}

variable "disk_size" {
  type    = string
  default = "51200"
}

variable "headless" {
  type    = string
  default = "false"
}

variable "memory" {
  type    = string
  default = "8192"
}

variable "name" {
  type    = string
  default = "${env("NAME")}"
}

variable "preseed_file_name" {
  type    = string
  default = "my-preseed.cfg"
}

variable "ssh_password" {
  type    = string
  default = "packer"
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

variable "ubuntu_images_url" {
  type    = string
  default = "${env("UBUNTU_IMAGES_URL")}"
}

source "qemu" "k3s" {
  accelerator      = "${var.accelerator}"
  boot_command     = ["<tab>", "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu-server/${var.preseed_file_name} ", "auto=true ", "net.ifnames=0 ", "hostname=localhost ", "<enter>"]
  boot_wait        = "10s"
  cpus             = "${var.cpus}"
  disk_size        = "${var.disk_size}"
  headless         = "${var.headless}"
  http_directory   = "http"
  iso_checksum     = "file:${var.ubuntu_images_url}/SHA256SUMS"
  iso_urls         = ["${var.ubuntu_images_url}/netboot/mini.iso"]
  memory           = "${var.memory}"
  output_directory = "${var.name}-qemu"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  ssh_password     = "${var.ssh_password}"
  ssh_timeout      = "1h"
  ssh_username     = "${var.ssh_username}"
  vm_name          = "${var.name}"
}

build {
  sources = ["source.qemu.k3s"]

  provisioner "shell" {
    inline = [
      "curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py",
      "sudo python3 /tmp/get-pip.py",
      "sudo pip3 install --ignore-installed ansible==7.2.0 pyyaml openshift kubernetes",
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
    inline = [
      "sudo apt autoremove",
    ]
  }
}
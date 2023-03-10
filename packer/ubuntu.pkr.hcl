variable "accelerator" {
  type    = string
  default = "kvm"
}

variable "cpus" {
  type    = number
  default = 4
}

variable "disk_size" {
  type    = string
  default = "4096M"
}

variable "headless" {
  type    = bool
  default = false
}

variable "memory" {
  type    = number
  default = 8192
}

variable "packer_log" {
  type = string
  default = env("PACKER_LOG")
}

variable "ssh_password" {
  type = string
  sensitive =  true
}

variable "ssh_username" {
  type = string
  sensitive =  true
}

variable "name" {
  type    = string
  default = "ubuntu_paas"
}

variable "ubuntu_release_name" {
  type    = string
  default = "jammy"
}

variable "ubuntu_version" {
  type    = string
  default = "22.04.2"
}

locals {
  ubuntu_download_url = "https://releases.ubuntu.com/${var.ubuntu_release_name}"
  ubuntu_image = "ubuntu-${var.ubuntu_version}-live-server-amd64.iso"
}

source "qemu" "k3s" {
  vm_name        = "${var.name}"
  iso_urls       = ["${local.ubuntu_download_url}/${local.ubuntu_image}"]
  iso_checksum   = "file:${local.ubuntu_download_url}/SHA256SUMS"
  http_directory = "http"
  boot_command = [
    "c",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ",
    "<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
  boot_wait        = "10s"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  memory           = "${var.memory}"
  cpus             = "${var.cpus}"
  disk_size        = "${var.disk_size}"
  accelerator      = "${var.accelerator}"
  vnc_port_min     = 5990
  headless         = var.headless
  communicator     = "ssh"
  ssh_timeout      = var.packer_log == "1" ? "35m" : "20m"
  ssh_password     = var.ssh_password
  ssh_username     = var.ssh_username
  host_port_max    = 2226
  output_directory = "${var.name}-qemu"
  disk_compression = true
}

build {
  sources = ["source.qemu.k3s"]

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"
    ]
  }

  provisioner "shell" {
    inline = [
      "curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py",
      "sudo python3 /tmp/get-pip.py",
      "sudo mkdir /playbook && sudo chown -R ${var.ssh_username}:${var.ssh_username} /playbook"
    ]
  }

  provisioner "ansible-local" {
    command                 = "sudo ansible-playbook"
    playbook_file           = "../playbook/site.yaml"
    playbook_dir            = "../playbook/"
    extra_arguments         = ["--skip-tags kubeapps"]
    galaxy_file             = "../playbook/requirements.yaml"
    galaxy_command          = "sudo pip3 install -r requirements.txt && sudo ansible-galaxy"
    galaxy_roles_path       = "/usr/share/ansible/roles"
    galaxy_collections_path = "/usr/share/ansible/collections"
    staging_directory       = "/playbook/"
  }

  # Cleanup and minimize
  provisioner "shell" {
    script = "scripts/remove-snap.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo apt autoremove -y --purge",
      "sudo apt autoclean -y",
      "sudo journalctl --vacuum-size 10M"
    ]
  }
}

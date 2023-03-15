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

variable "format" {
  type    = string
  default = "qcow2"
}

variable "packer_log" {
  type = string
  default = env("PACKER_LOG")
}

variable "ssh_password" {
  type = string
  sensitive =  true
}

variable "ssh_password_hash" {
  type = string
  sensitive =  true
}

variable "ssh_username" {
  type = string
  sensitive =  true
  default = "admin"
}

variable "ubuntu_release_name" {
  type    = string
  default = "jammy"
}

variable "ubuntu_version" {
  type    = string
  default = "22.04.2"
}

variable "locale" {
  type = string
  default = "fr_FR.UTF8"
}

variable "keyboard" {
  type = object({
    layout = string
    variant = string
  })
  default = {
    layout = "fr"
    variant = "fr"
  }
}

variable "playbook" {
  type = object({
    dir = string
    file = string
    extra_arguments = list(string)
  })
  default = {
    dir = "../playbook"
    file = "site.yaml"
    extra_arguments = ["--skip-tags kubeapps"]
  }
}

locals {
  ubuntu_download_url = "https://releases.ubuntu.com/${var.ubuntu_release_name}"
  ubuntu_image = "ubuntu-${var.ubuntu_version}-live-server-amd64.iso"
  cloud_init_params = {
    ssh_username = var.ssh_username
    ssh_password_hash = var.ssh_password_hash
    locale = var.locale
    keyboard = var.keyboard
  }
}

source "qemu" "ubuntu" {
  vm_name        = "ubuntu-${var.ubuntu_release_name}-${var.ubuntu_version}.${var.format}"
  iso_urls       = ["${local.ubuntu_download_url}/${local.ubuntu_image}"]
  iso_checksum   = "file:${local.ubuntu_download_url}/SHA256SUMS"
  http_content = {
    "meta-data" = file("${path.root}/http/meta-data")
    "user-data" = templatefile("${path.root}/http/user-data.tmpl", local.cloud_init_params)
  }
  boot_command = [
    "c",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ",
    "<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
  format           = var.format
  boot_wait        = "10s"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  memory           = "${var.memory}"
  cpus             = "${var.cpus}"
  disk_size        = "${var.disk_size}"
  qemu_img_args {
    convert = ["-o", "preallocation=metadata"]
  }
  accelerator      = "${var.accelerator}"
  vnc_port_min     = 5990
  headless         = var.headless
  communicator     = "ssh"
  ssh_timeout      = var.packer_log == "1" ? "35m" : "20m"
  ssh_password     = var.ssh_password
  ssh_username     = var.ssh_username
  host_port_max    = 2226
  output_directory = ".qemu-{{build_name}}/"
  disk_compression = true
}

build {
  sources = ["source.qemu.ubuntu"]

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
    playbook_file           = "${var.playbook.dir}/${var.playbook.file}"
    playbook_dir            = var.playbook.dir
    extra_arguments         = var.playbook.extra_arguments
    galaxy_file             = "${var.playbook.dir}/requirements.yaml"
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

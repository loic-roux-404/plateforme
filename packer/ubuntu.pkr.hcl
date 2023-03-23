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
  default = true
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
  type    = string
  default = env("PACKER_LOG")
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "ssh_password_hash" {
  type      = string
  sensitive = true
}

variable "ssh_username" {
  type      = string
  sensitive = true
  default   = "admin"
}

variable "locale" {
  type    = string
  default = "fr_FR.UTF-8"
}

variable "ubuntu_release_info" {
  type = object({
    name  = string
    version = string
  })
  default = {
    name  = "jammy"
    version = "22.04.2"
  }
}

variable "keyboard" {
  type = object({
    layout  = string
    variant = string
  })
  default = {
    layout  = "fr"
    variant = "fr"
  }
}

variable "playbook" {
  type = object({
    dir             = string
    file            = string
    extra_arguments = list(string)
  })
  default = {
    dir             = "../playbook"
    file            = "site.yaml"
    extra_arguments = ["--skip-tags kubeapps"]
  }
}

locals {
  ubuntu_download_url = "https://releases.ubuntu.com/${var.ubuntu_release_info.name}"
  ubuntu_image        = "ubuntu-${var.ubuntu_release_info.version}-live-server-amd64.iso"
}

source "qemu" "vm" {
  http_content = {
    "/meta-data" = ""
    "/user-data" = templatefile("${abspath(path.root)}/cloud-init.yaml.tmpl", {
      ssh_username      = var.ssh_username
      ssh_password_hash = var.ssh_password_hash
      locale            = var.locale
      keyboard          = var.keyboard
      hostname          = var.ubuntu_release_info.name
    })
  }
  boot_command = [
    "c",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ",
    "<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
  iso_urls         = ["${local.ubuntu_download_url}/${local.ubuntu_image}"]
  iso_checksum     = "file:${local.ubuntu_download_url}/SHA256SUMS"
  format           = var.format
  boot_wait        = "10s"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  disk_compression = true
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
  vm_name          = "ubuntu-${var.ubuntu_release_info.name}-${var.ubuntu_release_info.version}.${var.format}"
  output_directory = ".qemu-{{build_name}}/"
}

build {
  sources = ["source.qemu.vm"]

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait", 
      "sudo cloud-init clean --logs"
    ]
  }

  provisioner "shell" {
    inline = [
      "curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py",
      "sudo python3 /tmp/get-pip.py",
      "sudo mkdir /playbook && sudo chown -R ${var.ssh_username}:${var.ssh_username} /playbook",
      "sudo pip3 install ${replace(file("${var.playbook.dir}/requirements.txt"), "\n", " ")}"
    ]
  }

  provisioner "ansible-local" {
    command                 = "sudo ansible-playbook"
    galaxy_command          = "sudo ansible-galaxy"
    galaxy_roles_path       = "/usr/share/ansible/roles"
    galaxy_collections_path = "/usr/share/ansible/collections"
    staging_directory       = "/playbook/"
    playbook_file           = "${var.playbook.dir}/${var.playbook.file}"
    playbook_dir            = var.playbook.dir
    extra_arguments         = var.playbook.extra_arguments
    galaxy_file             = "${var.playbook.dir}/requirements.yaml"
  }

  # Cleanup and minimize
  provisioner "shell" {
    script = "scripts/remove-snap.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo apt autoremove -y --purge",
      "sudo apt autoclean -y",
      "sudo journalctl --rotate",
      "sudo journalctl --vacuum-size 10M"
    ]
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    output = "SHA256SUMS"
  }
}

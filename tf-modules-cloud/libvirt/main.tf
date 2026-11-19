locals {
  darwin_cmdline = var.darwin ? [
    "-netdev", "vmnet-shared,id=shared.0",
    "-device", "virtio-net-pci,netdev=shared.0,addr=0x9,mac=de:ad:be:ef:00:01"
  ] : []
  private_key = trimspace(file(pathexpand(var.ssh_connection.private_key)))
}

resource "libvirt_pool" "volumetmp" {
  name = "libvirt-paas-nixos-pool"
  type = "dir"
  target {
    path = var.libvirt_pool_path
  }
}

resource "libvirt_volume" "nixos" {
  name   = "nixos.qcow2"
  source = var.libvirt_qcow_source
  pool   = libvirt_pool.volumetmp.name
  format = "qcow2"
}

resource "libvirt_volume" "nixos_worker" {
  name           = "nixos-worker.qcow2"
  base_volume_id = libvirt_volume.nixos.id
  pool           = libvirt_pool.volumetmp.name
  # 16G death-spirals (kubelet image GC evicts pods mid-pull, Longhorn CSI
  # dies); 24G is the hard cap — the qcow lives on the macOS host disk
  size = var.disk_size_gib * 1024 * 1024 * 1024
}

resource "libvirt_domain" "machine" {
  name      = var.node_hostname
  vcpu      = 4
  memory    = 6144
  type      = "hvf"
  autostart = true
  arch      = var.arch

  disk {
    volume_id = libvirt_volume.nixos_worker.id
  }

  filesystem {
    source   = "/nix/store"
    target   = "nix-store"
    readonly = false
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  video {
    type = "vga"
  }

  cpu {
    mode = var.arch == "x86_64" ? "custom" : "host-passthrough"
  }

  xml {
    xslt = templatefile("${path.module}/nixos.xslt.tmpl", {
      args = local.darwin_cmdline
      type = var.arch == "x86_64" ? "'qemu'" : "@type"
    })
  }
}

data "external" "get_ip" {
  depends_on = [libvirt_domain.machine]
  program    = ["bash", "${path.module}/get-ip.sh"]
  query = {
    timeout = 120
    mac     = var.mac
  }
}

resource "terraform_data" "clean_ssh_known_hosts" {
  depends_on = [data.external.get_ip]
  provisioner "local-exec" {
    command = "ip='${data.external.get_ip.result.ip}'; [ -n \"$ip\" ] && ssh-keygen -R \"$ip\" || true"
  }
}

output "node_hostname" {
  depends_on = [libvirt_domain.machine]
  value      = var.node_hostname
}

output "node_id" {
  value = libvirt_domain.machine.id
}

output "node_ip" {
  value = data.external.get_ip.result.ip
}

locals {
  port_mappings = join(",", [for k, v in var.port_mappings : "hostfwd=tcp::${k}-:${v}"])
  darwin_cmdline = var.darwin ? [
    "-netdev", "vmnet-shared,id=shared.0",
    "-device", "virtio-net-pci,netdev=shared.0,addr=0x9,mac=de:ad:be:ef:00:01"
  ] : []
  private_key = trimspace(file(pathexpand(var.ssh_connection.private_key)))
}

resource "libvirt_pool" "volumetmp" {
  name = "libvirt-k3s-paas-nixos-pool"
  type = "dir"
  path = var.libvirt_pool_path
}

resource "libvirt_volume" "nixos" {
  name   = "nixos.qcow2"
  source = "${path.cwd}/result/nixos.qcow2"
  pool   = libvirt_pool.volumetmp.name
  format = "qcow2"
}

resource "libvirt_volume" "nixos_worker" {
  name           = "nixos-worker.qcow2"
  base_volume_id = libvirt_volume.nixos.id
  pool           = libvirt_pool.volumetmp.name
  size           = 16384 * 1024 * 1024
}

resource "libvirt_domain" "machine" {
  name      = var.node_hostname
  vcpu      = 2
  memory    = 4096
  type      = "hvf"
  autostart = true

  disk {
    volume_id = libvirt_volume.nixos_worker.id
  }

  filesystem {
    source   = "/nix/store"
    target   = "nix-store"
    readonly = false
  }

  filesystem {
    source   = "${path.cwd}/xchg"
    target   = "xchg"
    readonly = false
  }

  filesystem {
    source   = "${path.cwd}/xchg"
    target   = "shared"
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
    mode = "host-passthrough"
  }

  xml {
    xslt = templatefile("${path.module}/nixos.xslt.tmpl", {
      args = concat([
        "-netdev", "user,id=user.0,${local.port_mappings}",
        "-net", "nic,netdev=user.0,model=virtio,addr=0x8",
        ],
        local.darwin_cmdline
      )
    })
  }

  provisioner "local-exec" {
    command = "ssh-keygen -R [localhost]:22 && ssh-keygen -R [127.0.0.1]:22"
  }
}

output "name" {
  depends_on = [ libvirt_domain.machine ]
  value = var.node_hostname
}

output "id" {
  value = libvirt_domain.machine.id
}

output "ip" {
  value = "127.0.0.1"
  depends_on = [ libvirt_domain.machine ]
}

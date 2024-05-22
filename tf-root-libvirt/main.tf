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
  name      = "vm1"
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
    when    = create
    command = "ssh-keygen -R [localhost]:2222 && ssh-keygen -R [127.0.0.1]:2222"
  }
}

resource "null_resource" "ensure_started" {
  triggers = {
    domain_id = libvirt_domain.machine.id
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.ssh_connection.user
      host        = "localhost"
      private_key = local.private_key
      port        = "2222"
      agent       = false
      timeout     = "6m"
    }

    inline = ["echo 'Vm ${libvirt_domain.machine.id} started'"]
  }
}

resource "null_resource" "copy_k3s_config" {
  triggers = {
    domain_id = libvirt_domain.machine.id
  }
  provisioner "local-exec" {
    command = "ssh ${var.ssh_connection.user}@localhost -p 2222 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config"
  }
}

data "healthcheck_http" "k3s" {
  path         = "livez?verbose"
  status_codes = [200]
  endpoints = [
    {
      name    = "k3s-1"
      address = "127.0.0.1"
      port    = 6443
    },
  ]
}

data "healthcheck_filter" "k3s" {
  up   = data.healthcheck_http.k3s.up
  down = data.healthcheck_http.k3s.down
}

output "up_k3s_endpoint" {
  value = data.healthcheck_filter.k3s.up
}

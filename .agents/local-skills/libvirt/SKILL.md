---
name: terraform-libvirt-specialist
description: Specialized knowledge for provisioning virtual machines with terraform-provider-libvirt (dmacvicar/libvirt). Covers libvirt_domain, libvirt_volume, libvirt_pool, libvirt_network, cloud-init integration, NixOS image provisioning, CoW disk cloning, XSLT XML patching, macOS HVF/aarch64, bridge/NAT/shared networking, virtio-fs host sharing, virsh diagnostics, and integration with Terragrunt root modules. Use when writing or debugging HCL that targets the libvirt provider, editing domain XML templates, troubleshooting guest network or disk issues, managing storage pools/volumes, or automating local VM fleets for NixOS builds.
metadata:
  version: "1.0.0"
  domain: virtualization
  triggers: >
    libvirt, libvirt_domain, libvirt_volume, libvirt_pool, libvirt_network,
    libvirt_cloudinit_disk, dmacvicar/libvirt, terraform-provider-libvirt,
    qemu, kvm, hvf, virsh, virtio, virtiofs, 9p, qcow2, cloud-init,
    vcpus, memory, autostart, coreos_ignition, xslt, vmnet, aarch64
  role: virtualization-engineer
  scope: implementation
  output-format: code
---

# Terraform Libvirt Specialist

Senior Infrastructure Automation Engineer specialising in **terraform-provider-libvirt** (`dmacvicar/libvirt`), local VM fleet management, and NixOS/cloud-init provisioning pipelines.

## Role Definition

You design, debug, and optimise `libvirt_*` Terraform resources. You are equally comfortable with HCL module authoring, domain XML manipulation via XSLT, and `virsh` diagnostics. You understand the specific constraints of the k3s-paas project: **Terragrunt root modules**, NixOS images built from flakes, sops-age secret management, and nixos-rebuild remote deployment over SSH.

***

## Provider Setup

```hcl
# terraform.tf  (place in every module that uses libvirt)
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri   # e.g. "qemu:///system" or "qemu+ssh://user@host/system"
}
```

### Common URI patterns

| Environment | URI |
|---|---|
| Local Linux (system daemon) | `qemu:///system` |
| Local Linux (session daemon) | `qemu:///session` |
| macOS HVF | `qemu:///session` |
| Remote over SSH | `qemu+ssh://root@192.168.1.10/system` |
| Remote over TCP | `qemu+tcp://host/system` |

***

## Core Concepts & Patterns

### 1. Storage Pools & Volumes

Libvirt organises disks as `volumes` inside `pools`. Use **Copy-On-Write (CoW)** cloning for fast, space-efficient VM fleets:

- Declare one read-only base image as a `libvirt_volume` with `source` pointing to a locally-built NixOS `.qcow2`.
- Reference it via `base_volume_id` in overlay volumes — no data is copied, only deltas are written.
- Always set `format = "qcow2"` to enable snapshotting and CoW.

```hcl
resource "libvirt_pool" "volumetmp" {
  name = "libvirt-paas-nixos-pool"
  type = "dir"
  target {
    path = var.libvirt_pool_path   # default "/var/lib/libvirt-pools/kube-paas-pool"
  }
}

resource "libvirt_volume" "nixos_base" {
  name   = "nixos-base.qcow2"
  pool   = libvirt_pool.vms.name
  source = var.nixos_image_path   # absolute path to locally-built image
  format = "qcow2"
}

resource "libvirt_volume" "node_disk" {
  for_each       = var.nodes
  name           = "${each.key}.qcow2"
  pool           = libvirt_pool.vms.name
  base_volume_id = libvirt_volume.nixos_base.id
  size           = each.value.disk_size  # bytes, e.g. 20 * 1024^3
  format         = "qcow2"
}
```

### 2. Cloud-Init Disk

For non-NixOS guests (Ubuntu/Debian/Fedora) that consume cloud-init:

```hcl
resource "libvirt_cloudinit_disk" "init" {
  name      = "${var.node_name}-init.iso"
  pool      = libvirt_pool.vms.name
  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    hostname   = var.node_name
    ssh_keys   = var.ssh_authorized_keys
    extra_cmds = var.extra_commands
  })
  network_config = templatefile("${path.module}/templates/network.yaml.tpl", {
    interface = "eth0"
    dhcp      = true
  })
}
```

### 3. NixOS Images (k3s-paas pattern)

NixOS VMs do not use cloud-init. Instead:
1. Build a `.qcow2` with `nix build .#nixosConfigurations.<name>.config.system.build.qcow` outside Terraform.
2. Upload the image into a `libvirt_volume` via `source`.
3. Boot the VM — the NixOS config is already baked in.
4. Hand off to the **`tf-modules-nix/deploy`** module for `nixos-rebuild switch` over SSH.

```hcl
# In a Terragrunt root that wires libvirt + nix-deploy together:
module "vm" {
  source         = "../../tf-modules-cloud/libvirt"   # libvirt module
  nixos_image    = "/nix/store/.../nixos.qcow2"
  node_name      = "dev-node-01"
  vcpus          = 4
  memory_mb      = 4096
  libvirt_uri    = "qemu:///system"
}

module "deploy" {
  source           = "../../tf-modules-nix/deploy"
  node_address     = module.vm.ip_address
  node_id          = "dev-node-01"
  nix_flake        = "path:.#nixosConfigurations.dev-node-01"
  ssh_connection   = var.ssh_connection
  nixos_transient_secrets = var.secrets
  depends_on       = [module.vm]
}
```

### 4. macOS HVF Acceleration

When running on macOS Apple Silicon:
- Set `type = "hvf"` on `libvirt_domain`.
- Use `arch = "aarch64"` (or `x86_64` with Rosetta).
- Inject `vmnet-shared` via an XSLT template (the standard libvirt schema has no vmnet resource).
- The `xml { xslt = ... }` block on `libvirt_domain` is the escape hatch for all features not natively modelled.

### 5. VirtioFS / 9p Host Sharing

Share the Nix store or project workspace into the guest:

```hcl
filesystem {
  source   = "/nix/store"
  target   = "nix-store"    # mount tag inside the guest
  readonly = true
  accessmode = "passthrough"
}
```

Inside the NixOS guest, mount with:
```nix
fileSystems."/nix/.ro-store" = {
  device  = "nix-store";
  fsType  = "virtiofs";
  options = [ "ro" ];
};
```

***

## Network Resources

### NAT Network (default, no host bridge required)

```hcl
resource "libvirt_network" "nat" {
  name      = "plateforme-nat"
  mode      = "nat"
  domain    = "plateforme.local"
  addresses = ["192.168.122.0/24"]
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}
```

### Bridge Network (requires pre-created host bridge `br0`)

```hcl
resource "libvirt_network" "bridge" {
  name      = "plateforme-bridge"
  mode      = "bridge"
  bridge    = "br0"
}
```

### macOS vmnet-shared (via XSLT — no libvirt_network resource needed)

Use the XSLT escape in the domain definition (see Terraform templates below).

***

## Terraform Code Templates

### Full NixOS Node Module (Linux / `qemu:///system`)

```hcl
# tf-modules-cloud/libvirt/main.tf

variable "node_name"       {}
variable "nixos_image"     {}
variable "vcpus"           { default = 2 }
variable "memory_mb"       { default = 2048 }
variable "disk_size"       { default = 21474836480 }  # 20 GiB
variable "libvirt_pool"    { default = "default" }
variable "network_name"    { default = "default" }
variable "autostart"       { default = true }
variable "share_nix_store" { default = false }

resource "libvirt_volume" "disk" {
  name           = "${var.node_name}.qcow2"
  pool           = var.libvirt_pool
  base_volume_id = libvirt_volume.base[0].id
  size           = var.disk_size
  format         = "qcow2"
}

resource "libvirt_volume" "base" {
  count  = 1
  name   = "base-${basename(var.nixos_image)}"
  pool   = var.libvirt_pool
  source = var.nixos_image
  format = "qcow2"
}

resource "libvirt_domain" "node" {
  name      = var.node_name
  vcpu      = var.vcpus
  memory    = var.memory_mb
  autostart = var.autostart

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.disk.id
  }

  network_interface {
    network_name   = var.network_name
    wait_for_lease = true
  }

  dynamic "filesystem" {
    for_each = var.share_nix_store ? [1] : []
    content {
      source     = "/nix/store"
      target     = "nix-store"
      readonly   = true
      accessmode = "passthrough"
    }
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

output "ip_address" {
  value = libvirt_domain.node.network_interface[0].addresses[0]
}
```

### macOS HVF Domain with vmnet-shared (aarch64)

```hcl
resource "libvirt_domain" "mac_node" {
  name      = var.node_name
  vcpu      = var.vcpus
  memory    = var.memory_mb
  type      = "hvf"
  arch      = "aarch64"
  autostart = false   # session daemon: autostart not available on macOS

  disk {
    volume_id = libvirt_volume.disk.id
  }

  dynamic "filesystem" {
    for_each = var.share_nix_store ? [1] : []
    content {
      source     = "/nix/store"
      target     = "nix-store"
      readonly   = true
      accessmode = "passthrough"
    }
  }

  # vmnet-shared injected as raw QEMU args — libvirt XML has no vmnet element
  xml {
    xslt = <<-XSLT
      <xsl:stylesheet version="1.0"
          xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:output omit-xml-declaration="yes" indent="yes"/>
        <!-- identity transform -->
        <xsl:template match="node()|@*">
          <xsl:copy><xsl:apply-templates select="node()|@*"/></xsl:copy>
        </xsl:template>
        <!-- append qemu:commandline inside <devices> -->
        <xsl:template match="/domain/devices">
          <xsl:copy>
            <xsl:apply-templates select="node()|@*"/>
            <qemu:commandline
                xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0">
              <qemu:arg value="-netdev"/>
              <qemu:arg value="vmnet-shared,id=vmnet0"/>
              <qemu:arg value="-device"/>
              <qemu:arg
                value="virtio-net-pci,netdev=vmnet0,mac=${var.mac_address}"/>
            </qemu:commandline>
          </xsl:copy>
        </xsl:template>
      </xsl:stylesheet>
    XSLT
  }
}
```

## Variables Module (variables.tf)

```hcl
variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "nixos_image_path" {
  description = "Absolute path to the pre-built NixOS qcow2 image"
  type        = string
}

variable "node_name" {
  description = "Unique domain name (must be a valid libvirt domain name)"
  type        = string
}

variable "vcpus" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "RAM in MiB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Overlay disk size in bytes (on top of CoW base)"
  type        = number
  default     = 21474836480  # 20 GiB
}

variable "mac_address" {
  description = "Guest MAC address (required for macOS vmnet, must be in de:ad:be:ef:xx:xx range for vmnet)"
  type        = string
  default     = "de:ad:be:ef:00:01"
}

variable "share_nix_store" {
  description = "Mount /nix/store from host into guest via virtiofs"
  type        = bool
  default     = false
}
```

***

## Command Reference (virsh)

| Goal | Command |
|---|---|
| List all domains | `virsh list --all` |
| Start a VM | `virsh start <domain>` |
| Graceful shutdown | `virsh shutdown <domain>` |
| Force stop | `virsh destroy <domain>` |
| Serial console | `virsh console <domain>` |
| Get IP (DHCP lease) | `virsh domifaddr <domain>` |
| Dump full XML | `virsh dumpxml <domain>` |
| Edit XML live | `virsh edit <domain>` |
| List all pools | `virsh pool-list --all` |
| Refresh pool | `virsh pool-refresh <pool>` |
| List volumes in pool | `virsh vol-list --pool <pool>` |
| Delete volume | `virsh vol-delete --pool <pool> <vol>` |
| Domain info/stats | `virsh dominfo <domain>` |
| Network list | `virsh net-list --all` |
| Network DHCP leases | `virsh net-dhcp-leases <net>` |

***

## Debugging Checklist

### VM won't start
1. Check `virsh list --all` — is domain in `shut off` or `paused`?
2. `journalctl -u libvirtd` — look for permission/capability errors.
3. On macOS: confirm `type = "hvf"` and that `qemu` has Hypervisor.framework entitlement (`codesign -d --entitlements - $(which qemu-system-aarch64)`).
4. Pool path must exist and be writable: `virsh pool-refresh <pool>`.

### No IP address after `wait_for_lease = true`
1. `virsh net-dhcp-leases <network>` — did DHCP assign a lease?
2. Check guest interface is up: `virsh console <domain>` → `ip a`.
3. For macOS vmnet-shared: ensure the XSLT injects correctly with `virsh dumpxml <domain> | grep netdev`.
4. NAT network: ensure `iptables`/`nftables` forward rules are active (`sysctl net.ipv4.ip_forward`).

### Image import fails / volume already exists
- Terraform `taint libvirt_volume.base` then re-apply, or `virsh vol-delete` first.
- CoW overlay depends on base: always destroy domain before volume, and base last.

### macOS vmnet permission denied
- `sudo` required for vmnet on macOS; run `virsh` and QEMU as root or add entitlements.
- Check with: `system_profiler SPNetworkDataType | grep vmnet`.

***

## Constraints & Rules

- **Destroy order:** always destroy `libvirt_domain` before its `libvirt_volume` resources. Use `depends_on` in reverse or set `lifecycle { create_before_destroy = false }` where needed.
- **Portability:** prefer `cpu { mode = "host-passthrough" }` for same-arch isolation; use `custom` models when VMs must be portable across different CPU generations.
- **k3s-paas convention:** libvirt modules live in `tf-modules-cloud/libvirt/`, Terragrunt root compositions in `tf-root-*/`. Wire VM provisioning module output (`ip_address`) into the `tf-modules-nix/deploy` module input (`node_address`).
- **Secrets:** never embed secrets in cloud-init user data in plaintext. Use sops-age to encrypt and the `tf-modules-nix/deploy` upload pattern.
- **Image freshness:** track NixOS image changes via a `triggers_replace` on `libvirt_volume.base` referencing the image file hash: `sha256(filemd5(var.nixos_image_path))`.
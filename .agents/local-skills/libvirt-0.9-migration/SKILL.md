---
name: libvirt-0.9-migration
description: >
  Migration cookbook for terraform-provider-libvirt 0.8.x → 0.9.x (dmacvicar).
  Covers the 0.9.0 schema rewrite (generated, XML-mirroring schema), the 0.9.1
  attr renames, resource-by-resource HCL conversion, XSLT removal via
  qemu:commandline native support, state migration strategy, and validation.
  Use when migrating tf-modules-cloud/libvirt (or any libvirt_* HCL) from 0.8.3
  to 0.9.9, debugging "Invalid or unknown key" errors after a provider bump,
  or reviewing a libvirt 0.9 migration diff.
metadata:
  version: "1.0.0"
  domain: virtualization
  triggers: >
    libvirt 0.9, libvirt migration, provider upgrade, dmacvicar/libvirt,
    schema rewrite, xml block removed, xslt removed, cloudinit removed,
    accessmode, base_volume_id, libvirt_volume backing_store, qemu:commandline
  role: virtualization-engineer
  scope: implementation
  output-format: cookbook
---

# Libvirt Provider 0.8.x → 0.9.9 Migration Cookbook

Target: `dmacvicar/libvirt` **0.8.3 → 0.9.9** in `tf-modules-cloud/libvirt`.

## 0. What changed (context)

- **0.9.0**: full rewrite on the new plugin framework. Schema now generated
  from the libvirt XML schema (`libvirtxml`), HCL maps ~1:1 to domain XML.
  Old flat/abstracted attrs are gone. Legacy lives on the `v0.8` branch only.
- **0.9.1**: attr renames on top of 0.9.0 (camelCase → snake_case, value+unit
  pairs, nested variant objects for `<source>` elements).
- **0.9.2–0.9.9**: bugfixes + new capabilities relevant to us:
  - `qemu_commandline` / `qemu_capabilities` / `qemu_override` first-class
    domain attrs (0.9.5) — **replaces the XSLT hack**.
  - `terraform import` for `libvirt_domain` by UUID (0.9.6) — **replaces
    destroy+recreate for state adoption**.
  - Configurable shutdown timeout on update/destroy (0.9.4/0.9.6).
  - `dir` pool destroy no longer deletes the backing directory (0.9.4).
  - NVRAM/TPM files preserved on domain update (0.9.4).
  - `wait_for_ip` with CIDR filter + preserved across applies (0.9.9).
  - Volume `capacity` may exceed uploaded source image size (0.9.9).

## 1. Global rename rules (0.9.1 migration guide)

1. Attr names mirror libvirt XML, snake_case: `accessmode` → `access_mode`,
   `readonly` → `read_only`, `portgroup` → `port_group`.
2. Value/unit pairs are explicit: `memory` + `memory_unit`, `capacity` +
   `capacity_unit`. Unset unit = libvirt default (KiB for volumes).
3. Presence/"yes"/"no" semantics: XML string attrs take `"yes"`/`"no"`
   (e.g. `os.loader_readonly`); true XML `<feature/>` booleans stay Terraform
   bools (e.g. `features.acpi`).
4. Nested objects match the XML tree exactly — no flattened conveniences.
5. `metadata` string → `metadata = { xml = <<EOF ... EOF }`.
6. Set only fields you care about; null = absent from XML.

## 2. Resource-by-resource conversion

### 2.1 `terraform.tf` (provider constraint)

```hcl
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.9"   # was 0.8.3
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}
```

### 2.2 `libvirt_pool` — minimal change

`target { path = ... }` unchanged. New optional `create`/`destroy` lifecycle
blocks (experimental). **0.9.4 safety win**: destroying a `dir` pool no longer
deletes the backing directory (override with `destroy = { delete = true }`).

### 2.3 `libvirt_volume`

| 0.8.3 | 0.9.9 |
|---|---|
| `source = "/path/img.qcow2"` | `create = { content = { file = "/path/img.qcow2" } }` (or `url = ...`) |
| `format = "qcow2"` | `target = { format = { type = "qcow2" } }` |
| `size = 16 * 1024 * 1024 * 1024` | `capacity = 17179869184` + optional `capacity_unit = "B"` (default unit KiB — set explicitly) |
| `base_volume_id = <vol.id>` | `backing_store = { path = <vol.path>, format = { type = "qcow2" } }` |

CoW pattern for this repo (base qcow2 uploaded, worker overlay on top):

```hcl
resource "libvirt_volume" "nixos" {
  name = "nixos.qcow2"
  pool = libvirt_pool.volumetmp.name
  create = {
    content = { file = var.libvirt_qcow_source }
  }
  target = { format = { type = "qcow2" } }
}

resource "libvirt_volume" "nixos_worker" {
  name     = "nixos-worker.qcow2"
  pool     = libvirt_pool.volumetmp.name
  capacity = 16 * 1024 * 1024 * 1024
  capacity_unit = "B"
  backing_store = {
    path   = libvirt_volume.nixos.path
    format = { type = "qcow2" }
  }
}
```

Gotchas:
- 0.9.8: volumes **replace** when creation-time options change — expect
  recreate on `backing_store`/`create` edits, not in-place.
- 0.9.9: `capacity` may exceed the source image size (previously rejected).
- `allocation` + `allocation_unit` read-only on readback; creation-time
  `allocation` configurable since 0.9.9 (sparse volumes).
- `permissions.*` moved under `target.permissions.*`.

### 2.4 `libvirt_domain` — the big one

Top-level renames:

| 0.8.3 | 0.9.9 |
|---|---|
| `memory = 6144` | `memory = 6144` + `memory_unit = "MiB"` (unit now explicit; default is KiB — set it or values shift by 1024x) |
| `vcpu = 4` | `vcpu = 4` (unchanged) |
| `type = "hvf"` | `type = "hvf"` (unchanged, now Required) |
| `arch = "aarch64"` | `os = { type_arch = "aarch64" }` |
| `autostart` | `autostart` (unchanged) |
| `running` (new) | set `running = true` if the domain should be started |

Devices move under a single `devices = { ... }` object:

```hcl
resource "libvirt_domain" "machine" {
  name   = var.node_hostname
  type   = "hvf"
  vcpu   = 4
  memory = 6144
  memory_unit = "MiB"
  autostart = true
  running   = true

  os = {
    type      = "hvm"
    type_arch = var.arch
  }

  cpu = {
    mode = var.arch == "x86_64" ? "custom" : "host-passthrough"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_pool.volumetmp.name
            volume = libvirt_volume.nixos_worker.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      }
    ]

    # virtio-fs / 9p host share — nested, snake_case
    filesystems = [
      {
        source     = { mount = { dir = "/nix/store" } }
        target     = { dir = "nix-store" }
        read_only  = false
        access_mode = "passthrough"
      }
    ]

    consoles = [
      {
        type        = "pty"
        target_port = 0
        target_type = "serial"
      }
    ]

    videos = [
      { type = "vga" }
    ]
  }
}
```

Key device rules:
- Every `<source>` with mutually exclusive children becomes a **variant
  object**: `source = { volume = { pool, volume } }`, `source = { file = ... }`,
  `source = { block = ... }`, `source = { network = { network = "default" } }`.
- Network interfaces: `network_interface {}` blocks become
  `devices.interfaces = [{ source = { network = { network = "..." } }, wait_for_ip = { timeout = 300, source = "any", network = "<cidr>" } }]`.
  `wait_for_ip` (0.9.9) can replace the `get-ip.sh` external data source.

### 2.5 XSLT hack → native `qemu:commandline`

**The `xml { xslt = ... }` block no longer exists in 0.9.x.** Delete
`nixos.xslt.tmpl`. The 0.9.5 schema exposes the QEMU namespace directly:

```hcl
resource "libvirt_domain" "machine" {
  # ... as above ...

  # macOS vmnet-shared injection (replaces darwin_cmdline XSLT)
  qemu_commandline = {
    args = var.darwin ? [
      "-netdev", "vmnet-shared,id=shared.0",
      "-device", "virtio-net-pci,netdev=shared.0,addr=0x9,mac=de:ad:be:ef:00:01",
    ] : []
  }

  # x86_64 under Rosetta used XSLT to force type='qemu'; 0.9.x allows
  # setting type directly or via qemu_override if needed:
  # qemu_override = ... (only if type attr alone is insufficient)
}
```

Check the generated domain schema for the exact shape of `qemu_commandline`
(list of `{ value = ... }` objects vs flat args) before applying — consult the
registry docs page for `libvirt_domain` 0.9.9.

### 2.6 `libvirt_cloudinit_disk` — REMOVED as attachable convenience

0.9.x keeps `libvirt_cloudinit_disk` only as an ISO generator; the seed must be
uploaded as a volume and attached as a cdrom disk (see 0.9.0 release example).
Not used by this repo (NixOS images bake config in), but note it for any
future cloud-init guests.

### 2.7 `data "external" "get_ip"` — can be replaced

0.9.x offers `data "libvirt_domain_interface_addresses"` and `wait_for_ip` on
interfaces. Both can eliminate `get-ip.sh` + the MAC-based dnsmasq scrape:
- Preferred: `devices.interfaces[*].wait_for_ip = { source = "lease" }` and
  read the address from the domain state.
- Alternative: `data "libvirt_domain_interface_addresses" { domain = ..., source = "lease" }`.

Keep `get-ip.sh` only if wait_for_ip proves flaky with vmnet-shared
(vmnet leases are not visible to libvirt's lease source — verify; if so,
keep the external data source, it is provider-version independent).

## 3. State migration strategy

No automated state migration exists (explicitly stated by upstream). Options,
cheapest first:

1. **Import (recommended, 0.9.6+)** — keep the running VM, adopt into state:
   ```bash
   cd terragrunt/cloud/local   # layer that applies tf-modules-cloud/libvirt
   terragrunt state rm libvirt_domain.machine
   terragrunt import 'module.vm.libvirt_domain.machine' <domain-uuid>   # via virsh domuuid <name>
   terragrunt import 'module.vm.libvirt_volume.nixos' <pool>/<vol-name>
   terragrunt import 'module.vm.libvirt_pool.volumetmp' <pool-name>
   terragrunt plan   # must show no changes before done
   ```
   Volumes may also be imported by key (0.9.8).
2. **Destroy + recreate** — acceptable for the local dev VM (ephemeral, NixOS
   rebuilds anyway). Simplest path, loses only VM-local state.
3. **Never** hand-edit `terraform.tfstate` for the schema change.

Note: state lives at `.terragrunt/<env>/<path>/terraform.tfstate` (local
backend) — back it up before touching anything:
`cp -r .terragrunt .terragrunt.bak.$(date +%s)`.

## 4. Validation commands

```bash
nix develop                                   # dev shell with terragrunt
cd tf-modules-cloud/libvirt && terraform init -upgrade   # pull 0.9.9
terraform validate
# from repo root:
make terragrunt/cloud/local 1='plan'          # dry-run, expect recreate-or-import diff
virsh -c qemu:///system dominfo <name>        # cross-check libvirt view
```

Expected first `plan` after config rewrite: destroy+create of the domain (or
no-op if state imported cleanly). Volumes show recreate only if
creation-time attrs changed.

## 5. Rollback

- Revert `version = "0.8.3"` in `terraform.tf`, restore `main.tf` +
  `nixos.xslt.tmpl` from git, `terraform init -downgrade` (or `init` with the
  old pin), restore `.terragrunt` backup if state was touched.
- 0.8.x branch is unmaintained upstream — treat rollback as emergency-only.

## 6. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| `memory` unit default KiB | VM gets 1024x less RAM | Always set `memory_unit = "MiB"` |
| `qemu_commandline` exact shape unverified | Plan/apply failure | Read 0.9.9 registry docs before apply; test in isolation |
| vmnet-shared leases invisible to `wait_for_ip` | IP wait hangs | Keep `get-ip.sh` fallback; `source = "any"` first |
| Volume recreate on creation-attr change (0.9.8) | Worker disk data loss | Local dev only — acceptable; import instead if needed |
| Schema still marked experimental in parts (`create`/`destroy` blocks) | Future churn | Pin `0.9.9` exactly, do not use `~>` |

## 7. References

- Migration guide 0.9.0 → 0.9.1: https://github.com/dmacvicar/terraform-provider-libvirt/releases/tag/v0.9.1
- 0.9.0 rewrite announcement: https://github.com/dmacvicar/terraform-provider-libvirt/releases/tag/v0.9.0
- Registry docs (0.9.9): https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.9/docs

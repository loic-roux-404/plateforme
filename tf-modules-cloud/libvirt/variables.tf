variable "mac" {
  type = string
  default = "de:ad:be:ef:0:1"
}

variable "vm_size" {
  description = "vm size in MB"
  default     = "16G"
}

variable "disk_size_gib" {
  description = "Worker disk size in GiB. Guard rail: the qcow2 lives on the macOS host disk — raising this fills the laptop. Fix disk pressure by pruning VM images, not by growing the disk."
  type        = number
  default     = 24

  validation {
    condition     = var.disk_size_gib <= 24
    error_message = "Local dev VM disk is capped at 24 GiB (macOS host qcow2 growth). Do not raise it; prune unused VM images / Longhorn volumes instead."
  }
}

variable "darwin" {
  type    = bool
  default = true
}

variable "ssh_connection" {
  description = "values for the ssh connection"
  type = object({
    private_key = string
    user        = string
  })
  default = {
    private_key = "~/.ssh/id_ed25519"
    user        = "admin"
  }
}

variable "libvirt_pool_path" {
  default = "/var/lib/libvirt-pools/kube-paas-pool"
}

variable "node_hostname" {
  type    = string
  default = "localhost-0"
}

variable "arch" {
  type = string
  default = "x86_64"
}

variable "libvirt_qcow_source" {
  default = "result/nixos.qcow2"
}

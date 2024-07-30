variable "port_mappings" {
  type = map(number)
  default = {
    22   = 22
    443  = 443
    80   = 80
  }
}

variable "qemu_network_interface" {
  default = "en0"
}

variable "vm_size" {
  description = "vm size in MB"
  default     = 8092
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
  default = "/etc/libvirt/k3s-paas-pool"
}

variable "node_hostname" {
  type    = string
  default = "localhost-0"
}

variable "libvirt_qcow_source" {
  default = "result/nixos.qcow2"
}

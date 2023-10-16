variable "port_mappings" {
  type = map(number)
  default = {
    2222  = 22
    6443  = 6443
    443   = 443
    80    = 80
    32701 = 9701
    9701  = 9701
  }
}

variable "qemu_network_interface" {
  default = "en0"
}

variable "vm_size" {
  description = "vm size in MB"
  default     = 8092
}

variable "debug" {
  type    = bool
  default = false
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
    user        = "zizou"
  }
}

variable "libvirt_pool_path" {
  default = "/etc/libvirt/k3s-paas-pool"
}

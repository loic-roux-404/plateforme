variable "dex_client_id" {
  type = string
  sensitive = true
  default = "dex-k3s-paas"
}

variable "vm_ip" {
  type = string
}

variable "node_hostname" {
  type = string
  default = "k3s-paas-master"
}

variable "k3s_server_addr" {
  type = string
  default = null
}

variable "ssh_connection" {
  type = object({
    user        = string
    password    = string
    public_key  = string
    private_key = string
  })
  sensitive = true
}

variable "nix_flake" {
  default = ".#deploy"
}

variable "nixos_secrets" {
  type = map(string)
  default = {}
}

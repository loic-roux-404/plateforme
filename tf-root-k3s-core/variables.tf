variable "k3s_endpoint" {
  type = string
}

variable "k3s_port" {
  default = "6443"
}

variable "k3s_node_name" {
  type = string
}

variable "k3s_config" {
  sensitive = true
  type = object({
    cluster_ca_certificate = string
    client_certificate = string
    client_key = string
  })
}

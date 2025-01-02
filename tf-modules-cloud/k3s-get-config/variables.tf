variable "node_hostname" {
  type = string
}

variable "ssh_connection" {
  type = object({
    user        = string
    public_key  = string
    private_key = string
  })
  default = {
    private_key = "~/.ssh/id_ed25519"
    public_key  = "~/.ssh/id_ed25519.pub"
    user        = "admin"
  }
  sensitive = true
}

variable "remote_k3s_config_location" {
  default = "/etc/rancher/k3s/k3s.yaml"
}

variable "context_cluster_name" {
  type = string
  default = "default"
}

variable "context_user_name" {
  type = string
  default = "default"
}

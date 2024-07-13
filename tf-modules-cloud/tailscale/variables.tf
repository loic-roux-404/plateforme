variable "tailscale_trusted_device" {
  type = string
}

variable "trusted_ssh_user" {
  default = "admin"
}

variable "tailscale_tailnet" {
  type = string
}

variable "node_hostname" {
  type = string
}

variable "node_ip" {
  type = string
}

variable "node_id" {
  type = string
}

variable "tailscale_oauth_client" {
  sensitive = true
  type = object({
    id     = string
    secret = string
  })
}

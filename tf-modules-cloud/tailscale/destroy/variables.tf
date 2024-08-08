variable "tailscale_tailnet" {
  type = string
}

variable "node_hostname" {
  type = string
}

variable "tailscale_oauth_client" {
  sensitive = true
  type = object({
    id     = string
    secret = string
  })
}

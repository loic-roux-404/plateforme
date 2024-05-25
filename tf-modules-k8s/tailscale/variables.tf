variable "tailscale_namespace" {
  default = "tailscale"
}

variable "tailscale_oauth_client" {
  type = object({
    id     = string
    secret = string
  })
}

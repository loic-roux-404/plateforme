variable "tailscale_trusted_device" {
  type = string
}

variable "trusted_ssh_user" {
  default = "admin"
}

variable "tailscale_tailnet" {
  type = string
}

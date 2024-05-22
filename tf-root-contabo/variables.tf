variable "tailscale_trusted_device" {
  type = string
}

variable "tailscale_api_key" {
  type = string
}

# variable "tailscale_tailnet_id" {
#   type = string
# }

variable "trusted_ssh_user" {
  default = "zizou"
}

variable "paas_base_domain" {
  type    = string
  default = "k3s.test"
}

variable "domain_ttl" {
  type    = number
  default = 3000
}


variable "contabo_instance" {
  type = string
}

variable "contabo_credentials" {
  type = object({
    oauth2_client_id     = string
    oauth2_client_secret = string
    oauth2_user          = string
    oauth2_pass          = string
  })
  sensitive = true
}

variable "gandi_token" {
  type = string
}

variable "gandi_dnssec_public_key" {
  type = string
}

variable "image_url" {
  type    = string
  default = "https://github.com/loic-roux-404/k3s-paas/releases/download/nixos-a665502/nixos.qcow2"
}

variable "image_version" {
  type    = string
  default = "a665502"
}

variable "ssh_connection" {
  type = object({
    user          = string
    password      = string
    password_hash = string
    public_key    = string
    private_key   = string
  })
  default = {
    password      = "badSecret12!"
    password_hash = "$6$zizou$5kLDHHKr97WNOkvnTzpnqIQ/z.n.rJmV0YFdUiy1cwxxdz/wIgnI8Rd7lnO8Ry6t01KT3OLMhrFgOZiR7cMLb1"
    private_key   = "~/.ssh/id_rsa"
    public_key    = "~/.ssh/id_rsa.pub"
    user          = "admin"
  }
  sensitive = true
}

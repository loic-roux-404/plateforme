variable "tailscale_trusted_device" {
  type = string
}

variable "tailscale_api_key" {
  type = string
}

variable "trusted_ssh_user" {
  default = "admin"
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

variable "image_version" {
  default = "1817d1d"
}

variable "image_url_format" {
  default = "https://github.com/loic-roux-404/k3s-paas/releases/download/nixos-%s/nixos.qcow2"
}

variable "ssh_connection" {
  type = object({
    user          = string
    password      = string
    public_key    = string
    private_key   = string
  })
  default = {
    password      = "zizou420!"
    private_key   = "~/.ssh/id_ed25519"
    public_key    = "~/.ssh/id_ed25519.pub"
    user          = "admin"
  }
  sensitive = true
}

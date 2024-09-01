variable "machine" {
  type = object({
    node_hostname = string
    node_id       = string
    node_ip       = string
  })
}

### Gandi domain provider

variable "gandi_token" {
  type     = string
  nullable = true
}

variable "paas_base_domain" {
  type    = string
  default = "k3s.test"
}

variable "admin_password" {
  type      = string
  sensitive = true
  default   = "$6$zizou$reVO3q7LFsUq.GT5P5pYFFcpxCo7eTRT5yJTD.gVoOy/FSzHEtXdofvZ7E04Rej.jiQHKaWJB0Qob5FHov1WU/"
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

### Security

variable "tailscale_oauth_client" {
  sensitive = true
  type = object({
    id     = string
    secret = string
  })
}

variable "tailscale_tailnet" {
  type        = string
  description = "Like tailxxxxx.ts.net"
  nullable    = true
  sensitive   = true
}

variable "tailscale_expected_device" {
  default = "localhost"
}

variable "tailscale_trusted_device" {
  type = string
}

variable "nix_flake" {
  type = string
}

variable "nix_flake_reset" {
  type = string
}

variable "remote_k3s_config_location" {
  default = "/etc/rancher/rke2/rke2.yaml"
}

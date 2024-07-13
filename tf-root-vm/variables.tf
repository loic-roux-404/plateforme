variable "vm_provider" {
  description = "The provider to use for the VM"
  type        = string
  default     = "libvirt"
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

### Contabo

variable "contabo_credentials" {
  type = object({
    oauth2_client_id     = string
    oauth2_client_secret = string
    oauth2_user          = string
    oauth2_pass          = string
  })
  sensitive = true
}

variable "contabo_instance" {
  type     = string
  nullable = true
  default  = null
}

variable "image_version" {
  default = "57942d4"
}

variable "image_url_format" {
  default = "https://github.com/loic-roux-404/k3s-paas/releases/download/nixos-%s/nixos.qcow2"
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
  sensitive = true
}

variable "tailscale_trusted_device" {
  type = string
}

variable "dex_client_id" {
  type      = string
  sensitive = true
  default   = "dex-k3s-paas"
}

variable "secrets_file" {
  type = string
}

variable "libvirt_qcow_source" {
  type = string
}

variable "nix_flake" {
  type = string
}

variable "nix_deploy_force_rebuild" {
  type    = bool
  default = false
}

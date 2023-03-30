
variable "github_organization" {
  type = string
}

variable "github_team" {
  type = string
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "cert_manager_letsencrypt_env" {
  type    = string
  default = "prod"
}

variable "domain" {
  type = string
}

variable "domain_ttl" {
  type    = number
  default = 3000
}

variable "namedotcom_token" {
  type      = string
  sensitive = true
}

variable "namedotcom_username" {
  type      = string
  sensitive = true
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

variable "ansible_secrets" {
  type        = map(string)
  description = "Define ansible secrets"
  default     = {}
  sensitive   = true
}

variable "ubuntu_release_info" {
  type = object({
    name            = string
    version         = string
    iso_version_tag = string
    url             = string
    format          = string
  })
  default = {
    name            = "jammy"
    version         = "22.04.2"
    iso_version_tag = "ubuntu-jammy-fb3e35e"
    url             = "https://github.com:443/loic-roux-404/k3s-paas/releases/download"
    format          = "qcow2"
  }
}


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

# Contabo vars
variable "oauth2_client_id" {
  type      = string
  sensitive = true
}

variable "oauth2_client_secret" {
  type      = string
  sensitive = true
}

variable "oauth2_user" {
  type      = string
  sensitive = true
}

variable "oauth2_pass" {
  type      = string
  sensitive = true
}

variable "ssh_username" {
  type      = string
  sensitive = true
  default = "admin"
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "ssh_password_hash" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
  default   = "~/.ssh/id_rsa.pub"
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
    iso_version_tag = "ubuntu-jammy-563bd31"
    url             = "https://github.com/loic-roux-404/k3s-paas/releases/download"
    format          = "qcow2"
  }
}

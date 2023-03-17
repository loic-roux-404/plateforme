
variable "github_organization" {
  type = string
}

variable "github_team" {
  type = string
}

variable "github_token" {
  type = string
  sensitive = true
}

variable "cert_manager_letsencrypt_env" {
  type = string
  default = "prod"
}

variable "domain" {
  type = string
}

variable "domain_ttl" {
  type = number
  default = 3000
}

variable "namedotcom_token" {
  type = string
  sensitive = true
}

variable "namedotcom_username" {
  type = string
  sensitive = true
}

variable "contabo_instance" {
  type = string
}

# Contabo vars
variable "oauth2_client_id" {
  type = string
  sensitive = true
}

variable "oauth2_client_secret" {
  type = string
  sensitive = true
}

variable "oauth2_user" {
  type = string
  sensitive = true
}

variable "oauth2_pass" {
  type = string
  sensitive = true
}

variable "ssh_public_key" {
  type = string
  sensitive = true
  default = "~/.ssh/id_rsa.pub" 
}

variable "secrets" {
  type = map(string)
  description = "Define ansible secrets"
  default = {}
  sensitive = true
}

variable "os_image_url" {
  type = string
  default = "https://github.com/loic-roux-404/k3s-paas/releases/download/ubuntu-jammy-2204-boilerplate-850bf6f/ubuntu-jammy-22.04.2.qcow2"
}

variable "ubuntu_release_info" {
  type = object({
    name  = string
    version = string
  })
  default = {
    name  = "jammy"
    version = "22.04.2"
  }
}

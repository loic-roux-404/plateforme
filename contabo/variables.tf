
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

# TODO non prio
variable "secrets" {
  type = map(string)
  description = "Define Contabo secrets"
  default = {}
}

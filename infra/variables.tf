
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

variable "domain" {
  type = string
}

variable "namedotcom_token" {
  type = string
  sensitive = true
}

variable "namedotcom_username" {
  type = string
  sensitive = true
}

variable "secrets" {
  type = map(string)
  description = "Define Azure Key Vault secrets"
  default = {}
}

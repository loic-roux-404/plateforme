variable "paas_hostname" {
  description = "Hostname for paas"
  type        = string
  default = "paas.k3s.test"
}

variable "paas_token" {
  type = string
}

variable "dex_github_orgs" {
  description = "Github Orgs for Dex OIDC Connector"
  type        = list(object({
    name = string
    teams    = list(string)
  }))
  default     = []
}

variable "dex_hostname" {
  description = "Hostname for DEX"
  type        = string
}

variable "dex_client_id" {
  description = "Client ID for DEX"
  type        = string
}

variable "dex_client_secret" {
  description = "Client secret for DEX"
  type        = string
}

variable "dex_github_client_org" {
  default = "esgi-immo-scanner"
}

variable "dex_github_client_team" {
  default = "ops-team"
}

variable "tls_skip_verify" {
  default = true
}

variable "internal_acme_ca_content" {
  type = string
  sensitive = true
}

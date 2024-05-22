variable "paas_hostname" {
  description = "Hostname for paas"
  type        = string
  default     = "paas.k3s.test"
}

variable "paas_token" {
  type = string
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

variable "github_organization" {
  default = "org-404"
}

variable "github_team" {
  default = "ops-team"
}

variable "tls_skip_verify" {
  default = false
}

variable "internal_acme_ca_content" {
  type      = string
  sensitive = true
}

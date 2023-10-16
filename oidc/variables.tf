variable "paas_hostname" {
  description = "value of the waypoint hostname"
  default = "paas.k3s.test:443"
}

variable "paas_token" {
  type = string
}

variable "dex_hostname" {
  default = "dex.k3s.test"
}

variable "dex_client_id" {
  default = "paas"
}

variable "dex_client_secret" {
  default = "dex-client-secret"
}

variable "dex_github_client_org" {
  default = "esgi-immo-scanner"
}

variable "dex_github_client_team" {
  default = "ops-team"
}

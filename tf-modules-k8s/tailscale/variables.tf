variable "tailscale_namespace" {
  default = "tailscale"
}

variable "tailscale_oauth_client_id" {
  description = "OAuth Client ID"
  type        = string
  sensitive = true
}

variable "tailscale_oauth_client_secret" {
  description = "OAuth Client Secret"
  type        = string
  sensitive   = true
}

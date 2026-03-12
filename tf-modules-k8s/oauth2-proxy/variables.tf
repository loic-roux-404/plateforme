variable "client_name" {
  type        = string
  description = "Human-readable display name for the OIDC client"
}

variable "client_id" {
  type        = string
  description = "OIDC client ID. Defaults to client_name if not set."
  default     = ""
}

variable "client_secret" {
  type = string
}

variable "cookie_domains" {
  type = list(string)
}

variable "dex_namespace" {
  type        = string
  description = "Kubernetes namespace where Dex is deployed"
  default     = "dex"
}

variable "dex_hostname" {
  type        = string
  description = "Public hostname of the Dex OIDC provider"
}

variable "cert_manager_cluster_issuer" {
  type = string
  description = "value of the cert-manager cluster issuer"
}

variable "oauth2_hostname" {
  type        = string
  description = "Public hostname of the application using this OIDC client"
}

variable "redirect_uris" {
  type        = list(string)
  description = "Allowed redirect URIs for this OIDC client"
}

variable "github_org" {
  type        = string
  description = "GitHub organisation restricting access to this client"
}

variable "github_team" {
  type        = string
  description = "GitHub team slug within the organisation (leave empty for org-wide access)"
  default     = ""
}

variable "trusted_peers" {
  type        = list(string)
  description = "Client IDs trusted for cross-client token exchange"
  default     = []
}

variable "k8s_ingress_class" {
  description = "ingress class"
  type        = string
  default     = "nginx"
}

variable "oauth2_volume_mounts" {
  type = list(object({
    name      = string
    mountPath = string
    readOnly  = bool
  }))
  default = []
}

variable "oauth2_volumes" {
  type = list(object({
    name = string
    configMap = object({
      name = string
    })
  }))
  default = []
}

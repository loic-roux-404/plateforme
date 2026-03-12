variable "dex_namespace" {
  default = "dex"
}

variable "dex_hostname" {
  description = "Hostname for DEX"
  type        = string
}

variable "github_client_id" {
  description = "GitHub client ID for DEX"
  type        = string
}

variable "github_client_secret" {
  description = "GitHub client secret for DEX"
  type        = string
}

variable "static_clients" {
  type = list(object({
    id           = string
    redirectURIs = list(string)
    name         = string
    secret       = string
  }))
  sensitive = true
  default = []
}

variable "dex_github_orgs" {
  description = "Github Orgs for Dex OIDC Connector"
  type = list(object({
    name  = string
    teams = list(string)
  }))
  default = []
}

variable "k8s_ingress_class" {
  description = "ingress class"
  type        = string
  default     = "nginx"
}

variable "cert_manager_cluster_issuer" {
  description = "value of the cert-manager cluster issuer"
}

variable "dex_extra_volume_mounts" {
  type = list(object({
    name      = string
    mountPath = string
    readOnly  = bool
  }))
}

variable "dex_extra_volumes" {
  type = list(object({
    name = string
    configMap = object({
      name = string
    })
  }))
}

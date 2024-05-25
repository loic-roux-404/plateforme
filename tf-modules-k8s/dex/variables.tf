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

 variable "dex_client_id" {
   description = "Client ID for Dex OIDC Connector"
   type        = string
   default = "dex-k3s-paas"
 }

variable "dex_github_orgs" {
  description = "Github Orgs for Dex OIDC Connector"
  type = list(object({
    name  = string
    teams = list(string)
  }))
  default = []
}

variable "paas_hostname" {
  description = "Hostname for paas"
  type        = string
}

variable "k8s_ingress_class" {
  description = "ingress class"
  type        = string
  default     = "nginx"
}

variable "cert_manager_cluster_issuer" {
  description = "value of the cert-manager cluster issuer"
}

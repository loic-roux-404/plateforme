variable "n8n_hostname" {
  type = string
}

variable "n8n_version" {
  description = "community-charts/n8n chart version — see https://artifacthub.io/packages/helm/community-charts/n8n"
  type        = string
  default     = "1.16.33"
}

variable "cert_manager_cluster_issuer" {
  type = string
}

variable "ingress_annotations" {
  description = "nginx-ingress annotations to enforce Dex login via oauth2-proxy"
  type = map(string)
  default = {}
}

variable "k8s_ingress_class" {
  type = string
  default = "nginx"
}

variable "n8n_resources" {
  description = "CPU/memory requests and limits for the n8n main node"
  type = object({
    requests = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }))
    limits = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }))
  })
  default = {
    requests = { cpu = "100m", memory = "128Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "storage_class" {
  default = "local-path"
}

variable "n8n_persistence_size" {
  default = "128Mi"
}

variable "postgres_persistence_size" {
  default = "512Mi"
}

variable "valkey_persistence_size" {
  default = "256Mi"
}

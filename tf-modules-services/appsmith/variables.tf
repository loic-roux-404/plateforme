variable "k8s_ingress_annotations" {
  description = "nginx-ingress annotations to enforce Dex login via oauth2-proxy"
  type = map(string)
  default = {}
}

variable "cert_manager_cluster_issuer" {
  type = string
}

variable "k8s_ingress_class" {
  type = string
  default = "nginx"
}

variable "domain" {
  type = string
}

variable "chart_version" {
  default = "3.6.9"
}

variable "appsmith_resources" {
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
    requests = { cpu = "200m", memory = "512Mi" }
    limits   = { cpu = "800m", memory = "1536Mi" }
  }
}

variable "storage_class" {
  default = "local-path"
}

variable "postgres_persistence_size" {
  default = "512Mi"
}

variable "appsmith_persistence_size" {
  default = "128Mi"
}

variable "appsmith_mongodb_persistence_size" {
  default = "512Mi"
}

variable "appsmith_valkey_persistence_size" {
  default = "256Mi"
}

variable "appsmith_postgres_persistence_size" {
  default = "512Mi"
}

variable "appsmith_mongodb_resource_preset" {
  default = "small"
}

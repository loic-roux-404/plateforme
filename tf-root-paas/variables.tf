
variable "paas_base_domain" {
  default = "kube.test"
}

variable "cert_manager_letsencrypt_env" {
  default = "local"
}

variable "cert_manager_namespace" {
  default = "cert-manager"
}

variable "cert_manager_email" {
  type = string
}

variable "dex_namespace" {
  default = "dex"
}

variable "github_token" {
  sensitive = true
  type      = string
}

variable "github_client_id" {
  type = string
}

variable "github_client_secret" {
  type = string
}

variable "github_organization" {
  type    = string
  default = "org-404"
}

variable "github_team" {
  type    = string
  default = "ops-team-staging"
}

variable "github_apps_team" {
  default = "apps-team-staging"
}

variable "k3s_endpoint" {
  type = string
}

variable "k3s_port" {
  default = "6443"
}

variable "k3s_node_name" {
  type = string
}

variable "k3s_config" {
  sensitive = true
  type = object({
    cluster_ca_certificate = string
    client_certificate = string
    client_key = string
  })
}

variable "paas_namespace" {
  default = "default"
}

variable "k8s_ingress_class" {
  default     = "nginx"
  description = "ingress class"
}

variable "letsencrypt_envs" {
  description = "Letsencrypt Envs"
  type = object({
    local   = string
    staging = string
    prod    = string
  })
  default = {
    local   = "https://192.168.205.1:14000/dir"
    prod    = "https://acme-v02.api.letsencrypt.org/directory"
    staging = "https://acme-staging-v02.api.letsencrypt.org/directory"
  }
}

variable "letsencrypt_envs_ca_certs" {
  description = "Letsencrypt Envs CA Certs"
  type = object({
    local   = string
    staging = string
    prod    = string
  })
  default = {
    local   = "https://192.168.205.1:15000/roots/0"
    staging = "https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem"
    prod    = ""
  }
}

variable "services_subdomains" {
  default = [
    "n8n",
    "argocd",
    "grafana",
    "loki",
    "promtail",
    "prometheus",
    "alertmanager",
    "oauth2"
  ]
}

variable "dex_namespace" {
  default = "dex"
}

variable "k8s_ingress_class" {
  type = string
  default = "nginx"
}

variable "dex_hostname" {
  default = "dex.kube.test"
}

variable "n8n_subdomain" {
  default = "n8n"
}

variable "paas_base_domain" {
  default = "kube.test"
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

variable "github_organization" {
  default = "org-404"
}

variable "github_apps_team" {
  default = "apps-team-staging"
}

variable "k3s_config" {
  sensitive = true
  type = object({
    cluster_ca_certificate = string
    client_certificate = string
    client_key = string
  })
}

variable "cert_manager_cluster_issuer" {
  type = string
}

variable "github_token" {
  type = string
}

variable "github_username" {
  type = string
}

variable "oauth2_proxy_ingress_annotations" {
  type = map(string)
  default = {}
}

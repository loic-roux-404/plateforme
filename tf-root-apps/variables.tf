variable "n8n_subdomain" {
  default = "n8n"
}

variable "n8n_base_domain" {
  default = "kube.test"
}

variable "n8n_version" {
  default = "1.0.15"
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

variable "cert_manager_cluster_issuer" {
  type = string
}

variable "github_token" {
  type = string
}

variable "n8n_hostname" {
  type = string
}

variable "n8n_version" {
  type = string
  default = "2.0.1"
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

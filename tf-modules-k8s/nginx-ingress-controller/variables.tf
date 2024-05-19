variable "default_ssl_certificate" {
  type = bool
  default = false
}

variable "paas_base_domain" {
  default = "k3s.test"
}

variable "cert_manager_cluster_issuer" {
  description = "value of the cert-manager cluster issuer"
}

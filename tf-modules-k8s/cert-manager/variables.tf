variable "cert_manager_namespace" {
  description = "The namespace to install cert-manager into"
  type        = string
  default     = "cert-manager"
}

variable "k8s_ingress_class" {
  description = "The ingress class to use for cert-manager"
  type        = string
  default     = "nginx"
}

variable "cert_manager_email" {
  description = "The email to use for the letsencrypt account"
  type        = string
  default     = "test@k3s.test"
}

variable "internal_acme_ca_content" {
  description = "value of the acme ca cert"
  type        = string
}

variable "cert_manager_acme_url" {
  description = "The url of the acme server"
  type        = string
}

variable "letsencrypt_env" {
  description = "Environment to use for letsencrypt"
  default = "local"
}

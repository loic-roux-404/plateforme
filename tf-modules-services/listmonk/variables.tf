variable "namespace" {
  description = "Namespace pour Listmonk"
  type        = string
  default     = "listmonk"
}

variable "domain" {
  type = string
}

variable "cert_manager_cluster_issuer" {
  type = string
}

variable "k8s_ingress_class" {
  default = "nginx"
}

variable "chart_version" {
  description = "Version du Helm chart"
  type        = string
  default     = "0.1.12"
}

variable "ingress_annotations" {
  description = "nginx-ingress annotations to enforce Dex login via oauth2-proxy"
  type = map(string)
  default = {}
}

variable "listmonk_smtp_main_host" {
  description = "SMTP server host"
  type        = string
  default     = "smtp.gmail.com"
}

variable "listmonk_smtp_main_port" {
  description = "SMTP port (587 or 465)"
  type        = number
  default     = 587
}

variable "listmonk_smtp_main_username" {
  description = "SMTP username"
  type        = string
}

variable "listmonk_smtp_main_password" {
  description = "SMTP password"
  type        = string
  sensitive   = true
}

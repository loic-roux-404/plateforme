variable "namespace" {
  description = "Namespace pour Listmonk"
  type        = string
  default     = "supabase"
}

variable "domain" {
  type = string
}

variable "chart_version" {
  description = "Version du Helm chart"
  type        = string
  default     = "0.5.2"
}

variable "k8s_ingress_class" {
  default = "nginx"
}

variable "cert_manager_cluster_issuer" {
  type = string
}

variable "k8s_ingress_annotations" {
  description = "nginx-ingress annotations to enforce Dex login via oauth2-proxy"
  type = map(string)
  default = {}
}

variable "smtp_host" {
  description = "SMTP host service name"
  type        = string
}

variable "smtp_port" {
  description = "SMTP port"
  type        = number
}

variable "smtp_user" {
  description = "SMTP username"
  type        = string
}

variable "smtp_pass" {
  description = "SMTP password"
  type        = string
  sensitive   = true
}

variable "storage_class" {
  description = "StorageClass for Supabase PVCs"
  type        = string
  default     = "local-path"
}

variable "persistence_db_size" {
  description = "Size of persistentVolumeClaims for Supabase components"
  type        = string
  default     = "512Mi"
}

variable "persistence_minio_size" {
  description = "Size of persistentVolumeClaims for Supabase components"
  type        = string
  default     = "512Mi"
}

variable "persistence_size" {
  description = "Size of persistentVolumeClaims for Supabase components"
  type        = string
  default     = "256Mi"
}

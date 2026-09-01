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

variable "github_oauth_enabled" {
  description = "Enable GitHub OAuth for Supabase app users via GoTrue"
  type        = bool
  default     = false
  validation {
    condition     = !var.github_oauth_enabled || (var.github_client_id != "" && var.github_client_secret != "")
    error_message = "When github_oauth_enabled is true, both github_client_id and github_client_secret must be set."
  }
}

variable "github_client_id" {
  description = "GitHub OAuth app client ID (public, not secret)"
  type        = string
  default     = ""
}

variable "github_client_secret" {
  description = "GitHub OAuth app client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_redirect_allow_list" {
  description = "Extra allowed redirect origins as explicit globs (e.g. https://app.example.com/**). The module always prepends https://$${domain}/** itself."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for u in var.github_redirect_allow_list : startswith(u, "http://") || startswith(u, "https://")]) && !contains(var.github_redirect_allow_list, "*") && !contains(var.github_redirect_allow_list, "**")
    error_message = "Each github_redirect_allow_list entry must start with http:// or https:// and must not be a bare '*' or '**'."
  }
}

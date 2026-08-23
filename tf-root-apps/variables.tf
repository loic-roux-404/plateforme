variable "dex_namespace" {
  default = "dex"
}

variable "k8s_ingress_class" {
  type    = string
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
    client_certificate     = string
    client_key             = string
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
  type    = map(string)
  default = {}
}

variable "smtp_main_username" {
  description = "SMTP username"
  type        = string
  sensitive   = true
}

variable "smtp_main_password" {
  description = "SMTP password"
  type        = string
  sensitive   = true
}

variable "storage_class" {
  description = "Kubernetes StorageClass for stateful application PVCs (n8n, supabase, appsmith)"
  type        = string
  default     = "local-path"
}

variable "n8n_persistence_size" {
  default = "128Mi"
}

variable "n8n_postgres_persistence_size" {
  default = "512Mi"
}

variable "smtp_relay_persistence_size" {
  default = "128Mi"
}

variable "smtp_relay_storage_class" {
  description = "Kubernetes StorageClass for the Postfix relay queue PVC"
  type        = string
  default     = "local-path"
}

# Supabase app-user OAuth credentials. Populated from the SOPS-encrypted
# environment YAML (secrets/<env>.yaml) via terragrunt env.hcl
# sops_decrypt_file() — the decrypted `supabase` top-level key lands here by
# variable-name match. Never reference this variable in a non-sensitive output.
# Default keeps environments without the key (e.g. local) plan-safe; OAuth is
# enabled only when credentials are present.
variable "supabase" {
  description = "Supabase configuration from SOPS secrets (github OAuth client_id/client_secret)"
  type = object({
    github = object({
      client_id     = string
      client_secret = string
    })
  })
  sensitive = true
  default = {
    github = {
      client_id     = ""
      client_secret = ""
    }
  }
}

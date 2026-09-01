locals {
  n8n_hostname = "${var.n8n_subdomain}.${var.paas_base_domain}"
}

module "n8n" {
  source                      = "../tf-modules-services/n8n"
  n8n_hostname                = local.n8n_hostname
  cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
  ingress_annotations         = var.oauth2_proxy_ingress_annotations
  storage_class               = var.storage_class
  postgres_persistence_size   = var.n8n_postgres_persistence_size
  n8n_persistence_size        = var.n8n_persistence_size
}

module "mail-relay" {
  source                    = "../tf-modules-services/smtp-relay"
  relay_username            = var.smtp_main_username
  relay_password            = var.smtp_main_password
  persistence_size          = var.smtp_relay_persistence_size
  persistence_storage_class = var.smtp_relay_storage_class
}

module "supabase" {
  source = "../tf-modules-services/supabase"
  domain = "supabase.${var.paas_base_domain}"

  smtp_host                   = module.mail-relay.smtp_infos.host
  smtp_port                   = module.mail-relay.smtp_infos.port
  smtp_user                   = var.smtp_main_username
  smtp_pass                   = var.smtp_main_password
  cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
  storage_class               = var.storage_class

  # GitHub OAuth for Supabase application users (GoTrue). Credentials come from
  # the SOPS-encrypted env YAML. Enabled only when credentials are present so
  # environments without the supabase key (e.g. local) keep OAuth disabled.
  github_oauth_enabled       = var.supabase.github.client_id != "" && var.supabase.github.client_secret != ""
  github_client_id           = var.supabase.github.client_id
  github_client_secret       = var.supabase.github.client_secret
  github_redirect_allow_list = []
}

module "appsmith" {
  source                      = "../tf-modules-services/appsmith"
  domain                      = "appsmith.${var.paas_base_domain}"
  k8s_ingress_annotations     = var.oauth2_proxy_ingress_annotations
  cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
  storage_class               = var.storage_class
}

output "appsmith_mongodb_info" {
  value     = module.appsmith.mongodb_infos
  sensitive = true
}

output "supabase_dashboard_username" {
  description = "Supabase Studio login (username) — printed after apply for the operator to test login"
  value       = module.supabase.supabase_dashboard_username
  sensitive   = true
}

output "supabase_dashboard_password" {
  description = "Supabase Studio login (password) — printed after apply for the operator to test login"
  value       = module.supabase.supabase_dashboard_password
  sensitive   = true
}

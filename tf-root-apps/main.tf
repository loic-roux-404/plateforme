locals {
  n8n_hostname = "${var.n8n_subdomain}.${var.paas_base_domain}"
}

module "n8n" {
  source = "../tf-modules-services/n8n"
  n8n_hostname = local.n8n_hostname
  cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
  ingress_annotations = var.oauth2_proxy_ingress_annotations
  postgres_persistence_size = var.n8n_postgres_persistence_size
  n8n_persistence_size = var.n8n_persistence_size
}

module "mail-relay" {
  source = "../tf-modules-services/smtp-relay"
  relay_username        = var.smtp_main_username
  relay_password        = var.smtp_main_password
  persistence_size      = var.smtp_relay_persistence_size
}

module "supabase" {
  source = "../tf-modules-services/supabase"
  domain = "supabase.${var.paas_base_domain}"
  
  smtp_host = module.mail-relay.smtp_infos.host
  smtp_port = module.mail-relay.smtp_infos.port
  smtp_user = var.smtp_main_username
  smtp_pass = var.smtp_main_password
  cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
  k8s_ingress_annotations = var.oauth2_proxy_ingress_annotations
}

module "appsmith" {
  source =  "../tf-modules-services/appsmith"
  domain = "appsmith.${var.paas_base_domain}"
  k8s_ingress_annotations = var.oauth2_proxy_ingress_annotations
  cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
}

output "appsmith_mongodb_info" {
  value = module.appsmith.mongodb_infos
  sensitive = true
}

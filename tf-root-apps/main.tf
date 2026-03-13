locals {
  n8n_hostname = "${var.n8n_subdomain}.${var.paas_base_domain}"
}

module "n8n" {
  source = "../tf-modules-services/n8n"
  n8n_hostname = local.n8n_hostname
  cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
  ingress_annotations = var.oauth2_proxy_ingress_annotations
}

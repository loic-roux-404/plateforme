locals {
  cert_manager_acme_url         = var.letsencrypt_envs[var.cert_manager_letsencrypt_env]
  cert_manager_acme_ca_cert_url = var.letsencrypt_envs_ca_certs[var.cert_manager_letsencrypt_env]
  dex_hostname                  = "dex.${var.paas_base_domain}"
  paas_hostname                 = "paas.${var.paas_base_domain}"
  all_services_subdomains       = concat(["dex", "paas"], var.services_subdomains)
  ingress_hosts_internals       = [for item in local.all_services_subdomains : "${item}.${var.paas_base_domain}"] 
}

data "http" "paas_internal_acme_ca" {
  count    = local.cert_manager_acme_ca_cert_url != "" ? 1 : 0
  url      = local.cert_manager_acme_ca_cert_url
  insecure = var.cert_manager_letsencrypt_env == "local"
}

module "cluster_infos" {
  source = "../tf-modules-k8s/cluster-infos"
}

module "cert_manager" {
  depends_on               = [ module.cluster_infos ]
  source                   = "../tf-modules-k8s/cert-manager"
  internal_acme_ca_content = length(data.http.paas_internal_acme_ca) > 0 ? data.http.paas_internal_acme_ca[0].response_body : null
  cert_manager_acme_url    = local.cert_manager_acme_url
  letsencrypt_env          = var.cert_manager_letsencrypt_env
  cert_manager_email       = var.cert_manager_email
}

module "internal_ca" { 
   source                   = "../tf-modules-k8s/internal-ca"  
   for_each                 = var.cert_manager_letsencrypt_env == "local" ? toset(["internal-ca"]) : toset([])  
   ingress_hosts_internals  = local.ingress_hosts_internals  
   ingress_controller_ip    = module.cluster_infos.ingress_controller_ip
}

module "github" {
  source              = "../tf-modules-k8s/github"
  github_token        = var.github_token
  github_organization = var.github_organization
  github_team         = var.github_team
}

module "dex" {
  depends_on           = [module.cert_manager.reflector_metadata_name]
  source               = "../tf-modules-k8s/dex"
  dex_namespace        = var.dex_namespace
  dex_hostname         = local.dex_hostname
  github_client_id     = var.github_client_id
  github_client_secret = var.github_client_secret
  dex_github_orgs = [{
    name  = var.github_organization
    teams = [module.github.team_name]
  }]
  k8s_ingress_class           = var.k8s_ingress_class
  paas_hostname               = local.paas_hostname
  cert_manager_cluster_issuer = module.cert_manager.issuer
}

output "cert_manager_cluster_issuer" {
  value     = module.cert_manager.issuer
}

output "dex_client_secret" {
  sensitive = true
  value = module.dex.dex_client_secret
}

locals {
  cert_manager_acme_url         = var.letsencrypt_envs[var.cert_manager_letsencrypt_env]
  cert_manager_acme_ca_cert_url = var.letsencrypt_envs_ca_certs[var.cert_manager_letsencrypt_env]
  dex_hostname                  = "dex.${var.paas_base_domain}"
  paas_hostname                 = "paas.${var.paas_base_domain}"
  internal_acme_hostname        = "acme-internal.${var.paas_base_domain}"
  ingress_hosts_internals       = [var.paas_base_domain, local.dex_hostname, local.paas_hostname]
}

data "http" "paas_internal_acme_ca" {
  count    = local.cert_manager_acme_ca_cert_url != "" ? 1 : 0
  url      = local.cert_manager_acme_ca_cert_url
  insecure = var.cert_manager_letsencrypt_env == "local"
}

module "cilium" {
  count        = var.k8s_ingress_class == "cilium" ? 1 : 0
  source       = "../tf-modules-k8s/cilium"
  k3s_port     = var.k3s_port
  k3s_host     = var.k3s_endpoint
  node_name    = var.k3s_node_name 
}

module "metrics_server" {
  depends_on = [ module.cilium[0] ]
  source = "../tf-modules-k8s/metrics-server"
}

module "cert_manager" {
  depends_on               = [module.metallb[0], module.cilium[0]]
  source                   = "../tf-modules-k8s/cert-manager"
  internal_acme_ca_content = length(data.http.paas_internal_acme_ca) > 0 ? data.http.paas_internal_acme_ca[0].response_body : null
  cert_manager_acme_url    = replace(local.cert_manager_acme_url, "localhost", local.internal_acme_hostname)
  letsencrypt_env          = var.cert_manager_letsencrypt_env
  cert_manager_email       = var.cert_manager_email
}

locals {
  ingress_controller_ip = one(
    [for _, ci in module.cilium : ci.ingress_controller_ip]
  )
}

module "internal_ca" {
  source                   = "../tf-modules-k8s/internal-ca"
  for_each                 = var.cert_manager_letsencrypt_env == "local" ? toset(["internal-ca"]) : toset([])
  internal_acme_hostname   = local.internal_acme_hostname
  internal_acme_network_ip = var.internal_network_ip
  ingress_hosts_internals  = local.ingress_hosts_internals
  ingress_controller_ip    = local.ingress_controller_ip
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

module "paas" {
  depends_on                   = [module.dex.dex_ingress]
  source                       = "../tf-modules-k8s/waypoint"
  paas_hostname                = local.paas_hostname
  k8s_ingress_class            = var.k8s_ingress_class
  waypoint_extra_volume_mounts = module.cert_manager.root_ca_config_map_volume_mounts
  waypoint_extra_volumes       = module.cert_manager.root_ca_config_map_volume
  cert_manager_cluster_issuer  = module.cert_manager.issuer
}

module "paas_config" {
  source                   = "../tf-modules-k8s/waypoint-config"
  paas_hostname            = local.paas_hostname
  paas_token               = module.paas.token
  dex_hostname             = local.dex_hostname
  dex_client_secret        = module.dex.dex_client_secret
  github_team              = var.github_team
  tls_skip_verify          = var.cert_manager_letsencrypt_env == "local"
  internal_acme_ca_content = length(data.http.paas_internal_acme_ca) > 0 ? data.http.paas_internal_acme_ca[0].response_body : null
}

output "paas_token" {
  value     = module.paas.token
  sensitive = true
}

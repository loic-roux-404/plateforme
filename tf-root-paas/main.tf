module "cluster_infos" {
  source = "../tf-modules-k8s/cluster-infos"
}

locals {
  dex_hostname            = "dex.${var.paas_base_domain}"
  all_services_subdomains = concat(["dex", "longhorn"], var.services_subdomains)
  ingress_hosts_internals = [for item in local.all_services_subdomains : "${item}.${var.paas_base_domain}"]

  # Bucket names must be lowercase, 3-63 chars, DNS-compliant.
  # Derived here (composition layer) so the contabo-s3 module stays generic.
  repo_bucket_names = {
    for repo in module.github_org_repos_config.repositories :
    repo => lower(substr("${var.bucket_prefix}-${replace(repo, "/[^a-z0-9-]/", "-")}", 0, 63))
  }

  gateway_ip = "${substr(module.cluster_infos.ingress_controller_ip, 0, length(module.cluster_infos.ingress_controller_ip) - 1)}1"

  # Dynamic local environment URLs using gateway IP
  letsencrypt_envs_dynamic = merge(
    var.letsencrypt_envs,
    var.cert_manager_letsencrypt_env == "local" ? {
      local = "https://${local.gateway_ip}:14000/dir"
    } : {}
  )

  letsencrypt_envs_ca_certs_dynamic = merge(
    var.letsencrypt_envs_ca_certs,
    var.cert_manager_letsencrypt_env == "local" ? {
      local = "https://${local.gateway_ip}:15000/roots/0"
    } : {}
  )

  cert_manager_acme_url         = local.letsencrypt_envs_dynamic[var.cert_manager_letsencrypt_env]
  cert_manager_acme_ca_cert_url = local.letsencrypt_envs_ca_certs_dynamic[var.cert_manager_letsencrypt_env]
}

data "http" "paas_internal_acme_ca" {
  count    = local.cert_manager_acme_ca_cert_url != "" ? 1 : 0
  url      = local.cert_manager_acme_ca_cert_url
  insecure = var.cert_manager_letsencrypt_env == "local"
}

module "cert_manager" {
  depends_on               = [module.cluster_infos]
  source                   = "../tf-modules-k8s/cert-manager"
  internal_acme_ca_content = length(data.http.paas_internal_acme_ca) > 0 ? data.http.paas_internal_acme_ca[0].response_body : null
  cert_manager_acme_url    = local.cert_manager_acme_url
  letsencrypt_env          = var.cert_manager_letsencrypt_env
  cert_manager_email       = var.cert_manager_email
}

module "longhorn" {
  source                      = "../tf-modules-k8s/longhorn"
  paas_base_domain            = var.paas_base_domain
  k8s_ingress_class           = var.k8s_ingress_class
  cert_manager_cluster_issuer = module.cert_manager.issuer
  object_storage              = var.object_storage
  backup_bucket               = module.contabo_s3_longhorn.bucket_name
  ingress_annotations         = module.oauth2_proxy_apps.ingress_annotations
}

module "contabo_s3_longhorn" {
  source      = "../tf-modules-cloud/contabo-s3"
  bucket_name = lower(substr("${var.bucket_prefix}-longhorn", 0, 63))
}

module "internal_ca" {
  source                  = "../tf-modules-k8s/internal-ca"
  for_each                = var.cert_manager_letsencrypt_env == "local" ? toset(["internal-ca"]) : toset([])
  ingress_hosts_internals = local.ingress_hosts_internals
  ingress_controller_ip   = module.cluster_infos.ingress_controller_ip
}

module "github_ops" {
  source              = "../tf-modules-github/team"
  github_token        = var.github_token
  github_organization = var.github_organization
  github_team         = var.github_team
  roles               = ["admin"]
  description         = "The Ops team"
}

module "github_apps" {
  source              = "../tf-modules-github/team"
  github_token        = var.github_token
  github_organization = var.github_organization
  github_team         = var.github_apps_team
  description         = "The applications team"
}

resource "random_password" "github_apps_client_secret" {
  length  = 32
  special = false
}

resource "random_password" "github_ops_client_secret" {
  length  = 32
  special = false
}

resource "random_password" "github_action_client_secret" {
  length  = 32
  special = false
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
    teams = [module.github_ops.team_name, module.github_apps.team_name]
  }]
  k8s_ingress_class           = var.k8s_ingress_class
  cert_manager_cluster_issuer = module.cert_manager.issuer
  dex_extra_volume_mounts     = module.cert_manager.root_ca_config_map_volume_mounts
  dex_extra_volumes           = module.cert_manager.root_ca_config_map_volume
  static_clients = [{
    id           = module.github_apps.team_name
    name         = module.github_apps.team_name
    secret       = random_password.github_ops_client_secret.result
    redirectURIs = ["https://oauth2.${var.paas_base_domain}/oauth2/callback"]
    public       = false
    }, {
    id   = module.github_ops.team_name
    name = module.github_ops.team_name
    redirectURIs = [
      "http://127.0.0.1/oidc/callback",
      "http://localhost:8000"
    ]
    secret = random_password.github_ops_client_secret.result
    public = false
    }, {
    id           = var.github_action_client_id
    name         = var.github_action_client_id
    public       = true
    redirectURIs = []
    secret       = random_password.github_action_client_secret.result
  }]
}

resource "kubernetes_cluster_role_binding_v1" "dex_github_cluster_admin" {
  for_each = toset(["${var.github_organization}:${module.github_ops.team_name}"])

  metadata {
    name = "kubeapps-${replace(each.value, ":", "-")}-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = each.value
    api_group = "rbac.authorization.k8s.io"
  }
}

module "contabo_s3" {
  for_each    = local.repo_bucket_names
  source      = "../tf-modules-cloud/contabo-s3"
  bucket_name = each.value
}

module "github_org_repos_config" {
  source              = "../tf-modules-github/repos-config"
  github_token        = var.github_token
  github_organization = var.github_organization
  repo_secrets = {
    DEX_CLIENT_SECRET = random_password.github_action_client_secret.result
    DEX_CLIENT_ID     = var.github_action_client_id
    KUBE_CA           = base64encode(var.k3s_config.cluster_ca_certificate)
    S3_ACCESS_KEY     = var.object_storage.access_key
    S3_SECRET_KEY     = var.object_storage.secret_key
  }

  repo_variables = {
    "${var.repo_variables_prefix}dex_url"     = "https://${local.dex_hostname}"
    "${var.repo_variables_prefix}k8s_api_url" = "https://${var.paas_base_domain}:${var.k3s_port}"
    "${var.repo_variables_prefix}s3_endpoint" = var.object_storage.s3_url != "" ? var.object_storage.s3_url : "https://${var.object_storage.region}.contabostorage.com"
  }

  per_repo_variables = {
    for repo, bucket in local.repo_bucket_names :
    repo => { "${var.repo_variables_prefix}s3_bucket" = bucket }
  }
}

data "kubernetes_all_namespaces" "cluster_namespaces" {}

resource "kubernetes_role_binding_v1" "dex_github_apps_deployer" {
  for_each = toset(
    setintersection(
      toset(concat(var.ci_authorized_namespaces, module.github_org_repos_config.repositories)),
      toset(data.kubernetes_all_namespaces.cluster_namespaces.namespaces)
    )
  )

  metadata {
    name      = "kubeapps-${module.github_apps.team_name}-deployer"
    namespace = each.value
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  subject {
    kind = "User"
    name = var.github_organization
  }
}

module "oauth2_proxy_apps" {
  source                      = "../tf-modules-k8s/oauth2-proxy"
  client_name                 = module.dex.dex_clients[0].name
  client_id                   = module.dex.dex_clients[0].id
  client_secret               = module.dex.dex_clients[0].secret
  dex_namespace               = var.dex_namespace
  dex_hostname                = local.dex_hostname
  cookie_domains              = [".${var.paas_base_domain}"]
  cert_manager_cluster_issuer = module.cert_manager.issuer
  oauth2_hostname             = "oauth2.${var.paas_base_domain}"
  github_org                  = var.github_organization
  github_team                 = var.github_apps_team
  redirect_uris               = module.dex.dex_clients[0].redirectURIs
  oauth2_volume_mounts        = module.cert_manager.root_ca_config_map_volume_mounts
  oauth2_volumes              = module.cert_manager.root_ca_config_map_volume
  k8s_ingress_class           = var.k8s_ingress_class
}

output "cert_manager_cluster_issuer" {
  value = module.cert_manager.issuer
}

output "dex_clients" {
  sensitive = true
  value     = module.dex.dex_clients
}

output "dex_hostname" {
  value = module.dex.dex_hostname
}

output "github_apps_team" {
  value = module.github_apps.team_name
}

output "github_ops_team" {
  value = module.github_ops.team_name
}

output "oauth2_proxy_ingress_annotations" {
  sensitive = true
  value     = module.oauth2_proxy_apps.ingress_annotations
}

locals {
  dex_client_ops = [
    for client in module.dex.dex_clients :
    client
    if client.id == module.github_ops.team_name
  ][0]
}

output "oidc_login_setup_command_ops" {
  sensitive = true
  value     = <<EOF
kubectl config set-credentials oidc \
  --exec-api-version=client.authentication.k8s.io/v1 \
  --exec-interactive-mode=Never \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg="--oidc-issuer-url=https://dex.${var.paas_base_domain}" \
  --exec-arg="--oidc-client-id=${local.dex_client_ops.id}" \
  --exec-arg="--oidc-client-secret=${local.dex_client_ops.secret}" \
  --exec-arg="--oidc-extra-scope=groups" \
  --exec-arg="--oidc-extra-scope=email";

kubectl config set-cluster plateforme --server=https://${var.paas_base_domain}:6443;
kubectl config set clusters.plateforme.certificate-authority-data '${base64encode(var.k3s_config.cluster_ca_certificate)}';

kubectl config set-context plateforme --user=oidc --cluster=plateforme;

kubectl config use-context plateforme;
EOF
}

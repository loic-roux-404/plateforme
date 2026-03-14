

resource "random_password" "cookie_secret" {
  length  = 16
  special = false
}

locals {
  cookie_secret = base64encode(random_password.cookie_secret.result)
  # GitHub groups in Dex are formatted as "org:team"
  allowed_groups = var.github_team != "" ? ["${var.github_org}:${var.github_team}"] : [var.github_org]
  issuer_url     = "https://${var.dex_hostname}"
}

resource "helm_release" "oauth2_proxy" {
  name             = "${var.client_name}-oauth2-proxy"
  repository       = "https://oauth2-proxy.github.io/manifests"
  chart            = "oauth2-proxy"
  namespace        = var.dex_namespace
  create_namespace = false
  timeout          = 120

  values = [templatefile("${path.module}/oauth2-proxy-values.yaml.tmpl", {
    client_id       = var.client_id
    client_secret   = var.client_secret
    cookie_domains   = var.cookie_domains
    cookie_secret   = local.cookie_secret
    issuer_url      = local.issuer_url
    redirect_url    = var.redirect_uris.0
    allowed_groups  = local.allowed_groups
    oauth2_hostname    = var.oauth2_hostname
    oauth2_volumes = var.oauth2_volumes
    oauth2_volume_mounts = var.oauth2_volume_mounts
    ingress_class   = var.k8s_ingress_class
    cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
  })]

}

data "kubernetes_service_v1" "oauth2_proxy" {
  depends_on = [helm_release.oauth2_proxy]

  metadata {
    name      = "${var.client_name}-oauth2-proxy"
    namespace = var.dex_namespace
  }
}

output "issuer_url" {
  description = "Dex OIDC issuer URL"
  value       = local.issuer_url
}

output "ingress_annotations" {
  sensitive = true
  depends_on = [helm_release.oauth2_proxy]
  description = "nginx-ingress annotations to enforce Dex login via oauth2-proxy"
  value = {
    "nginx.ingress.kubernetes.io/auth-url" = "http://${data.kubernetes_service_v1.oauth2_proxy.metadata[0].name}.${var.dex_namespace}.svc.cluster.local:4180/oauth2/auth"
    "nginx.ingress.kubernetes.io/auth-signin" = "https://${var.oauth2_hostname}/oauth2/start?rd=$scheme://$host$escaped_request_uri"
    "nginx.ingress.kubernetes.io/auth-response-headers" = "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Groups,Authorization"
  }
}

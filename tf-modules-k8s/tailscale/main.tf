resource "kubernetes_namespace" "tailscale" {
  metadata {
    name = var.tailscale_namespace
  }
}

resource "helm_release" "tailscale_operator" {
  name              = "tailscale"
  repository        = "https://pkgs.tailscale.com/helmcharts"
  chart             = "tailscale-operator"
  namespace         = kubernetes_namespace.tailscale.metadata.0.name
  wait_for_jobs = true
  wait          = true

  set {
    name = "oauth.clientId"         
    value = var.tailscale_oauth_client_id
  }

  set {
    name = "apiServerProxyConfig.mode"
    value = "true"
    type = "string"
  }

  set {
    name = "oauth.clientSecret"     
    value = var.tailscale_oauth_client_secret
  }
}

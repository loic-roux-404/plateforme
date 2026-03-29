 resource "kubernetes_namespace_v1" "dex" {
  metadata {
    name = var.dex_namespace
  }
}

resource "helm_release" "dex" {
  repository       = "https://charts.dexidp.io"
  name             = "dex"
  namespace        = kubernetes_namespace_v1.dex.metadata[0].name
  chart            = "dex"
  timeout          = 180
  wait_for_jobs    = true
  atomic           = true
  take_ownership = true

  values = [
    templatefile("${path.module}/values.yaml.tmpl", {
      dex_hostname                = var.dex_hostname,
      github_client_id            = var.github_client_id,
      github_client_secret        = var.github_client_secret,
      dex_github_orgs             = jsonencode(var.dex_github_orgs),
      k8s_ingress_class           = var.k8s_ingress_class,
      cert_manager_cluster_issuer = var.cert_manager_cluster_issuer,
      dex_extra_volume_mounts      = var.dex_extra_volume_mounts,
      dex_extra_volumes            = var.dex_extra_volumes,
      dex_tls_volumes              = [{
        name = "tls",
        secret = {
          "secretName" = "${var.dex_hostname}-tls"
        }
      }]
      dex_tls_volume_mounts        = [{
        name = "tls",
        mountPath = "/tls",
        readOnly = true
      }]
      static_clients = var.static_clients
    })
  ]
}

data "kubernetes_service_v1" "dex_service" {
  metadata {
    name      = "dex"
    namespace = kubernetes_namespace_v1.dex.metadata[0].name
  }
}

data "kubernetes_ingress_v1" "dex_ingress" {
  metadata {
    name      = "dex"
    namespace = kubernetes_namespace_v1.dex.metadata[0].name
  }
}

output "dex_ingress" {
  value = data.kubernetes_ingress_v1.dex_ingress.id
}

output "dex_service" {
  value = data.kubernetes_service_v1.dex_service.id
}

output "dex_hostname" {
  value = data.kubernetes_ingress_v1.dex_ingress.id != null ? var.dex_hostname : null
}

output "dex_clients" {
  depends_on = [ data.kubernetes_service_v1.dex_service ]
  sensitive = true
  value = var.static_clients
}

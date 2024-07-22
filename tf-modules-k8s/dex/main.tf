resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = var.dex_namespace
  }
}

resource "random_password" "dex_client_secret" {
  length  = 24
  special = false
}

locals {
  dex_client_secret = random_password.dex_client_secret.result
}

resource "helm_release" "dex" {
  repository    = "https://charts.dexidp.io"
  name          = "dex"
  namespace     = kubernetes_namespace.cert-manager.metadata[0].name
  chart         = "dex"
  timeout       = 600
  wait_for_jobs = true
  atomic        = true

  values = [
    templatefile("${path.module}/values.yaml.tmpl", {
      dex_hostname                = var.dex_hostname,
      github_client_id            = var.github_client_id,
      github_client_secret        = var.github_client_secret,
      dex_github_orgs             = jsonencode(var.dex_github_orgs),
      dex_client_id               = var.dex_client_id,
      paas_hostname               = var.paas_hostname,
      dex_client_secret           = local.dex_client_secret,
      k8s_ingress_class           = var.k8s_ingress_class
      cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
    })
  ]
}

data "kubernetes_service" "dex_service" {
  metadata {
    name      = "dex"
    namespace = kubernetes_namespace.cert-manager.metadata[0].name
  }
}

data "kubernetes_ingress" "dex_ingress" {
  metadata {
    name      = "dex"
    namespace = kubernetes_namespace.cert-manager.metadata[0].name
  }
}

output "dex_ingress" {
  value = data.kubernetes_ingress.dex_ingress.id
}

output "dex_service" {
  value = data.kubernetes_service.dex_service.id
}

output "dex_client_secret" {
  value = local.dex_client_secret
}

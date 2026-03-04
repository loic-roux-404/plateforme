resource "helm_release" "valkey" {
  name       = "valkey"
  repository = var.valkey_helm_repo
  chart      = "valkey"
  version    = var.valkey_chart_version

  namespace        = var.valkey_namespace
  create_namespace = true

  values = [
    templatefile("${path.module}/valkey-values.yaml.tmpl", {
      valkey_service_name        = "${var.valkey_service_name}"
      replica_count              = var.replica_count
      data_storage_enabled       = var.data_storage_enabled
      data_storage_requestedSize = var.data_storage_requestedSize
      data_storage_className     = var.data_storage_className
      data_storage_keepPvc       = var.data_storage_keepPvc
    })
  ]
}

data "kubernetes_service" "valkey" {
  metadata {
    name      = var.valkey_service_name
    namespace = var.valkey_namespace
  }

  depends_on = [ helm_release.valkey ]
}

output "valkey_service_name" {
  description = "Name of the Kubernetes Service exposing Valkey"
  value       = data.kubernetes_service.valkey.metadata[0].name
}

output "valkey_service_cluster_ip" {
  description = "ClusterIP of the Valkey service"
  value       = data.kubernetes_service.valkey.spec[0].cluster_ip
}

output "valkey_service_port" {
  description = "First service port for Valkey"
  value       = data.kubernetes_service.valkey.spec[0].port[0].port
}

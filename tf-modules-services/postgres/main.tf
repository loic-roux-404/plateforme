resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  version    = var.postgresql_version
  namespace  = var.postgres_namespace
  create_namespace = true

  wait_for_jobs = true
  wait = true
  timeout = 120
  atomic = true

  values = [
    templatefile("${path.module}/postgres-values.yaml.tmpl", {
      postgres_password = random_password.postgres_password.result
      postgres_db       = var.postgres_db
      postgres_user     = var.postgres_user
      service_name      = var.postgres_service_name
      postgres_persistence_size = var.postgres_persistence_size
      postgres_storage_class = var.postgres_storage_class
    })
  ]
}

data "kubernetes_service_v1" "postgresql" {
  metadata {
    name      = var.postgres_service_name
    namespace = var.postgres_namespace
  }

  depends_on = [helm_release.postgresql]
}

locals {
  service_name = data.kubernetes_service_v1.postgresql.metadata[0].name
  cluster_ip   = data.kubernetes_service_v1.postgresql.spec[0].cluster_ip
  host         = "${local.service_name}.${var.postgres_namespace}.svc.cluster.local"
  service_port = data.kubernetes_service_v1.postgresql.spec[0].port[0].port
  password     = random_password.postgres_password.result
}

output "postgres_password" {
  value     = local.password
  sensitive = true
}

output "postgres_db" {
  value = var.postgres_db
}

output "postgres_user" {
  value = var.postgres_user
}

output "postgres_service_name" {
  description = "Name of the Kubernetes Service exposing PostgreSQL"
  value       = local.service_name
}

output "postgres_service_cluster_ip" {
  description = "ClusterIP of the PostgreSQL service"
  value       = local.cluster_ip
}

output "host" {
  value = local.host
}

output "postgres_service_port" {
  description = "First service port for PostgreSQL"
  value       = local.service_port
}

output "connection_string" {
  value = "postgresql://${var.postgres_user}:${local.password}@${local.service_name}.${var.postgres_namespace}.svc.cluster.local:${local.service_port}/${var.postgres_db}?sslmode=disable"
}

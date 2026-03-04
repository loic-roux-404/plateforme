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

  values = [
    templatefile("${path.module}/postgres-values.yaml.tmpl", {
      postgres_password = random_password.postgres_password.result
      postgres_db       = var.postgres_db
      postgres_user     = var.postgres_user
      service_name      = var.postgres_service_name
    })
  ]
}

data "kubernetes_service" "postgresql" {
  metadata {
    name      = var.postgres_service_name
    namespace = var.postgres_namespace
  }

  depends_on = [helm_release.postgresql]
}

output "postgres_password" {
  value     = random_password.postgres_password.result
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
  value       = data.kubernetes_service.postgresql.metadata[0].name
}

output "postgres_service_cluster_ip" {
  description = "ClusterIP of the PostgreSQL service"
  value       = data.kubernetes_service.postgresql.spec[0].cluster_ip
}

output "postgres_service_port" {
  description = "First service port for PostgreSQL"
  value       = data.kubernetes_service.postgresql.spec[0].port[0].port
}

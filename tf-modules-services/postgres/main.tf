resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "oci://registry-1.docker.io/bitnami"
  chart      = "postgresql"
  version    = variable.postgresql_version
  namespace  = "postgresql"
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

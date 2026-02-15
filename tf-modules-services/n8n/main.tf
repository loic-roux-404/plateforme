
module "n8n_postgres" {
  source = "../postgres"
  postgres_db = "n8n"
  postgres_user = "n8n"
  postgres_service_name = "n8n-postgres"
}

resource "helm_release" "n8n" {
  name       = "n8n"
  repository = "oci://8gears.container-registry.com/library"
  chart      = "n8n"
  version    = var.n8n_version
  namespace  = "n8n"
  create_namespace = true

  values = [
    templatefile("${path.module}/n8n-values.yaml.tmpl", {
      n8n_encryption_key = random_password.n8n_encryption_key.result
      n8n_password = n8n_postgres.postgres_password
      cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
      n8n_hostname = var.n8n_hostname
    })
  ]
}

output "n8n_encryption_key" {
  description = "The generated encryption key for n8n (save this securely!)"
  value       = random_password.n8n_encryption_key.result
  sensitive   = true
}

output "n8n_postgres_db" {
  description = "postgres db n8n (save this securely!)"
  value       =  n8n_postgres.postgres_db
  sensitive   = true
}

output "n8n_postgres_user" {
  description = "postgres user n8n (save this securely!)"
  value       =  n8n_postgres.postgres_user
  sensitive   = true
}

output "n8n_postgres_password" {
  description = "password for postgres user n8n (save this securely!)"
  value       =  n8n_postgres.postgres_password
  sensitive   = true
}

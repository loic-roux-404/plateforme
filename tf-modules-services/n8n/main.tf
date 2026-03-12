# Kubernetes provider
resource "kubernetes_namespace_v1" "n8n" {
  metadata {
    name = "n8n"
  }
}

module "valkey" {
  source = "../valkey"

  valkey_namespace      = kubernetes_namespace_v1.n8n.metadata[0].name
  valkey_helm_repo      = "https://valkey.io/valkey-helm"
  replica_count         = 1

  data_storage_enabled       = true
  data_storage_requestedSize = "256Mi"
  data_storage_className     = "local-path"
  data_storage_keepPvc       = false
}


module "n8n_postgres" {
  source = "../postgres"
  postgres_db = "n8n"
  postgres_user = "n8n"
  postgres_service_name = "n8n-postgres"
  postgres_namespace = kubernetes_namespace_v1.n8n.metadata[0].name
}

resource "random_password" "n8n_encryption_key" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "helm_release" "n8n" {
  name       = "n8n"
  repository = "oci://8gears.container-registry.com/library"
  chart      = "n8n"
  version    = var.n8n_version
  namespace        = kubernetes_namespace_v1.n8n.metadata[0].name
  create_namespace = false

  values = [
    templatefile("${path.module}/n8n-values.yaml.tmpl", {
      valkey_hostname        = "${module.valkey.valkey_service_name}.${kubernetes_namespace_v1.n8n.metadata[0].name}.svc.cluster.local"
      valkey_service_port = module.valkey.valkey_service_port

      n8n_encryption_key = random_password.n8n_encryption_key.result
      postgres_host = module.n8n_postgres.postgres_service_name
      postgres_db = module.n8n_postgres.postgres_db
      postgres_user = module.n8n_postgres.postgres_user
      postgres_password = module.n8n_postgres.postgres_password
      cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
      n8n_hostname = var.n8n_hostname
      ingress_class = var.k8s_ingress_class
      ingress_annotations = merge({
        "kubernetes.io/ingress.class"                    = var.k8s_ingress_class
        "cert-manager.io/cluster-issuer"                 = var.cert_manager_cluster_issuer
        "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
        #"nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
        "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
        }, var.ingress_annotations
      )
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
  value       =  module.n8n_postgres.postgres_db
  sensitive   = true
}

output "n8n_postgres_user" {
  description = "postgres user n8n (save this securely!)"
  value       =  module.n8n_postgres.postgres_user
  sensitive   = true
}

output "n8n_postgres_password" {
  description = "password for postgres user n8n (save this securely!)"
  value       =  module.n8n_postgres.postgres_password
  sensitive   = true
}

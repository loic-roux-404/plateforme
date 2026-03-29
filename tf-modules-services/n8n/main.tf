resource "kubernetes_namespace_v1" "n8n" {
  metadata {
    name = "n8n"
  }
}

module "valkey" {
  source = "../valkey"

  valkey_namespace           = kubernetes_namespace_v1.n8n.metadata[0].name
  valkey_helm_repo           = "https://valkey.io/valkey-helm"
  replica_count              = 1
  data_storage_enabled       = true
  data_storage_requestedSize = var.valkey_persistence_size
  data_storage_className     = var.storage_class
  data_storage_keepPvc       = false
}

module "n8n_postgres" {
  source                    = "../postgres"
  postgres_db               = "n8n"
  postgres_user             = "n8n"
  postgres_service_name     = "n8n-postgres"
  postgres_namespace        = kubernetes_namespace_v1.n8n.metadata[0].name
  postgres_persistence_size = var.postgres_persistence_size
  postgres_storage_class    = var.storage_class
}

resource "random_password" "n8n_encryption_key" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

locals {
  n8n_helm_values = {
    db = {
      type = "postgresdb"
    }

    externalPostgresql = {
      host     = module.n8n_postgres.postgres_service_name
      port     = 5432
      database = module.n8n_postgres.postgres_db
      username = module.n8n_postgres.postgres_user
      password = module.n8n_postgres.postgres_password
    }

    encryptionKey = random_password.n8n_encryption_key.result

    main = {
      count = 1

      persistence = {
        enabled = true
        accessMode = "ReadWriteOnce"
        size = var.n8n_persistence_size
        storageClass = var.storage_class
      }
      resources = var.n8n_resources
    }

    worker = {
      mode = "queue"
    }

    externalRedis = {
      host     = "${module.valkey.valkey_service_name}.${kubernetes_namespace_v1.n8n.metadata[0].name}.svc.cluster.local"
      port     = module.valkey.valkey_service_port
    }

    ingress = {
      enabled   = true
      className = var.k8s_ingress_class
      annotations = merge(
        {
          "kubernetes.io/ingress.class"                 = var.k8s_ingress_class
          "cert-manager.io/cluster-issuer"              = var.cert_manager_cluster_issuer
          "nginx.ingress.kubernetes.io/proxy-body-size" = "50m"
          "nginx.ingress.kubernetes.io/ssl-redirect"    = "true"
        },
        var.ingress_annotations
      )
      hosts = [
        {
          host = var.n8n_hostname
          paths = [
            {
              path     = "/"
              pathType = "Prefix"
            }
          ]
        }
      ]
      tls = [
        {
          hosts      = [var.n8n_hostname]
          secretName = "${var.n8n_hostname}-tls"
        }
      ]
    }
  }
}

resource "helm_release" "n8n" {
  name             = "n8n"
  repository       = "https://community-charts.github.io/helm-charts"
  chart            = "n8n"
  version          = var.n8n_version
  namespace        = kubernetes_namespace_v1.n8n.metadata[0].name
  create_namespace = false

  timeout         = 180
  wait_for_jobs   = true
  atomic          = true

  values = [yamlencode(local.n8n_helm_values)]
}

output "n8n_encryption_key" {
  description = "The generated encryption key for n8n (save this securely!)"
  value       = random_password.n8n_encryption_key.result
  sensitive   = true
}

output "n8n_postgres_db" {
  description = "postgres db for n8n"
  value       = module.n8n_postgres.postgres_db
  sensitive   = true
}

output "n8n_postgres_user" {
  description = "postgres user for n8n"
  value       = module.n8n_postgres.postgres_user
  sensitive   = true
}

output "n8n_postgres_password" {
  description = "password for postgres user n8n"
  value       = module.n8n_postgres.postgres_password
  sensitive   = true
}

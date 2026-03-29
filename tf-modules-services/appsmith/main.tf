resource "kubernetes_namespace_v1" "appsmith" {
  metadata {
    name = "appsmith"
  }
}

data "kubernetes_nodes" "all" {}

locals {
  appsmith_nodes = [
    for node in data.kubernetes_nodes.all.nodes : node.metadata.0.name
  ]
}

module "valkey" {
  source = "../valkey"

  valkey_namespace = kubernetes_namespace_v1.appsmith.metadata[0].name
  valkey_helm_repo = "https://valkey.io/valkey-helm"
  replica_count    = 1

  data_storage_enabled       = true
  data_storage_requestedSize = var.appsmith_valkey_persistence_size
  data_storage_className     = var.storage_class
  data_storage_keepPvc       = false
}

module "mongodb" {
  source                   = "../mongodb"
  namespace                = kubernetes_namespace_v1.appsmith.metadata[0].name
  name                     = "appsmith-mongodb"
  replica_count            = 3
  mongodb_persistence_size = var.appsmith_mongodb_persistence_size
  mongodb_storage_class    = var.storage_class
  mongodb_resource_preset  = var.appsmith_mongodb_resource_preset
}

module "appsmith_postgres" {
  source = "../postgres"

  postgres_db               = "appsmith-pg"
  postgres_user             = "appsmith"
  postgres_service_name     = "appsmith-postgres"
  postgres_namespace        = kubernetes_namespace_v1.appsmith.metadata[0].name
  postgres_persistence_size = var.postgres_persistence_size
  postgres_storage_class    = var.storage_class
}

resource "helm_release" "appsmith" {
  name             = "appsmith"
  namespace        = kubernetes_namespace_v1.appsmith.metadata[0].name
  repository       = "https://helm.appsmith.com"
  chart            = "appsmith"
  version          = var.chart_version
  create_namespace = false

  timeout       = 240
  wait_for_jobs = true
  atomic        = true

  values = [
    yamlencode({

      mongodb    = { enabled = false }
      redis      = { enabled = false }
      postgresql = { enabled = false }

      _image = {
        repository = "appsmith/appsmith-ce"
      }

      persistence = {
        enabled       = true
        storageClass  = var.storage_class
        size          = var.appsmith_persistence_size
        accessModes   = ["ReadWriteOnce"]
        reclaimPolicy = "Delete"
        localStorage  = true
        storagePath   = "/appsmith-stacks"
        localCluster  = local.appsmith_nodes
      }

      applicationConfig = {
        APPSMITH_DISABLE_EMBEDDED_KEYCLOAK = "1"
        APPSMITH_DB_URL                    = module.mongodb.connection_string
        APPSMITH_KEYCLOAK_DB_URL           = "${module.appsmith_postgres.host}:${module.appsmith_postgres.postgres_service_port}"
        APPSMITH_KEYCLOAK_DB_USERNAME      = module.appsmith_postgres.postgres_user
        APPSMITH_KEYCLOAK_DB_PASSWORD      = module.appsmith_postgres.postgres_password
        APPSMITH_KEYCLOAK_DB_DRIVER        = "postgresql"
        APPSMITH_REDIS_URL                 = "redis://${module.valkey.valkey_service_cluster_ip}:${module.valkey.valkey_service_port}"
        APPSMITH_CHAT_DB_URL               = module.appsmith_postgres.connection_string
        APPSMITH_MAIL_ENABLED              = "false"
        APPSMITH_FORM_LOGIN_DISABLED       = "false"
        APPSMITH_SIGNUP_DISABLED           = "false"
      }

      ingress = {
        enabled          = true
        ingressClassName = var.k8s_ingress_class
        hostname         = var.domain

        annotations = merge(
          var.k8s_ingress_annotations,
          {
            "cert-manager.io/cluster-issuer" = var.cert_manager_cluster_issuer
          }
        )

        tls = true
        certManagerTls = [
          {
            hosts      = [var.domain]
            secretName = "${var.domain}-tls"
          }
        ]
      }

      resources = var.appsmith_resources

    })
  ]
}

output "mongodb_infos" {
  value     = module.mongodb
  sensitive = true
}

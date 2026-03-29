
resource "random_password" "mongodb_root_password" {
  length           = 16
  special          = true
  override_special = "_%"
}

resource "random_password" "mongodb_password" {
  length           = 24
  special          = true
  override_special = "_%"
}

resource "random_password" "mongodb_replica_set_key" {
  length           = 12
  special          = false
}

resource "random_string" "mongodb_username" {
  length  = 12
  upper   = false
  lower   = true
  numeric = true
  special = false
}

resource "random_string" "mongodb_database" {
  length  = 10
  upper   = false
  lower   = true
  numeric = true
  special = false
}

locals {
  auth_root_password = random_password.mongodb_root_password.result
  auth_username      = random_string.mongodb_username.result
  auth_password      = random_password.mongodb_password.result
  auth_database      = random_string.mongodb_database.result
  replica_set_key    = random_password.mongodb_replica_set_key.result
}

resource "helm_release" "mongodb" {
  name             = var.name
  namespace        = var.namespace
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "mongodb"
  version          = var.chart_version
  create_namespace = false

  timeout          = 240
  wait_for_jobs    = true
  atomic           = true
  take_ownership = true

  set_sensitive = [{
    name  = "auth.rootPassword"
    value = local.auth_root_password
  }, {
    name  = "auth.usernames[0]"
    value = local.auth_username
  }, {
    name  = "auth.passwords[0]"
    value = local.auth_password
  }, {
    name  = "auth.databases[0]"
    value = local.auth_database
  }, {
    name  = "auth.replicaSetKey"
    value = local.replica_set_key
  }]

  values = [
    yamlencode({
      architecture = var.replica_count > 2 ? "replicaset" : "standalone"
      replicaCount = var.replica_count

      resourcesPreset = var.mongodb_resource_preset

      auth = {
        enabled  = true
        rootUser = "root"
      }

      persistence = {
        enabled      = true
        storageClass = var.mongodb_storage_class
        size         = var.mongodb_persistence_size
      }

      persistentVolumeClaimRetentionPolicy = {
        whenDeleted = "Delete"
        whenScaled  = "Retain"
      }
    })
  ]
}

data "kubernetes_service_v1" "mongo" {
  metadata {
    name      = "${var.name}${var.replica_count > 2 ? "-headless" : ""}"
    namespace = var.namespace
  }

  depends_on = [helm_release.mongodb]
}

locals {
  appsmith_db_replica_set_query = var.replica_count > 2 ? "&replicaSet=rs0" : ""
  appsmith_db_user_enc          = urlencode(local.auth_username)
  appsmith_db_password_enc      = urlencode(local.auth_password)
  host                          = "${data.kubernetes_service_v1.mongo.metadata[0].name}.${var.namespace}.svc.cluster.local"
  port                          = data.kubernetes_service_v1.mongo.spec[0].port[0].port
}

output "database_name" {
  value = local.auth_database
}

output "username" {
  value = local.auth_username
}

output "password" {
  value     = local.auth_password
  sensitive = true
}

output "host" {
  value = local.host
}

output "port" {
  value = local.port
}

output "root_password" {
  value     = local.auth_root_password
  sensitive = true
}

output "replicaset_name" {
  value = "rs0"
}

output "connection_string" {
  value = "mongodb://${local.appsmith_db_user_enc}:${local.appsmith_db_password_enc}@${local.host}:${local.port}/${local.auth_database}?authSource=${local.auth_database}${local.appsmith_db_replica_set_query}"
  sensitive = true
}

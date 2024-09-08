resource "random_password" "mongo_root_password" {
  length  = 16
  special = true
}

resource "helm_release" "mongodb" {
  name       = "mongo-db"
  chart      = "mongodb"
  repository = "https://charts.bitnami.com/bitnami"
  version    = var.mongo_version
  namespace  = "mongo"
  atomic           = true
  wait_for_jobs    = true
  timeout          = 180
  create_namespace = true

  values = [
    <<EOF
auth:
  enabled: true
  username: ${var.mongo_root_user}
  password: "${random_password.mongo_root_password.result}"
  database: "root-db"
EOF
  ]
}

output "mongo_root_user" {
  value = var.mongo_root_user
}

output "mongo_root_password" {
  value = random_password.mongo_root_password.result
}

output "mongodb_uri" {
  value = "mongodb://${helm_release.mongodb.name}-mongodb.mongo.svc.cluster.local:27017"
}

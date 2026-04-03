resource "kubernetes_namespace_v1" "supabase" {
  metadata {
    name = var.namespace
  }
}

resource "random_password" "supabase_jwt_secret" {
  length  = 40
  special = false
}

resource "random_password" "supabase_anon_key_suffix" {
  length           = 43
  special          = true
  override_special = "_-"
}

resource "random_password" "supabase_service_key_suffix" {
  length           = 43
  special          = true
  override_special = "_-"
}

resource "random_password" "supabase_db_user" {
  length  = 16
  special = false
}

resource "random_password" "supabase_db_password" {
  length  = 32
  special = true
}

resource "random_password" "supabase_analytics_public_token" {
  length  = 40
  special = false
}

resource "random_password" "supabase_analytics_private_token" {
  length  = 40
  special = false
}

resource "random_password" "supabase_realtime_secret_key_base" {
  # Phoenix SECRET_KEY_BASE — chart docs say: openssl rand -base64 64
  length  = 64
  special = true
}

resource "random_password" "supabase_meta_crypto_key" {
  # Chart docs say: openssl rand -hex 32 → 64 hex chars, lowercase alphanumeric
  length  = 64
  special = false
  upper   = false
}

resource "random_password" "supabase_minio_password" {
  length  = 24
  special = false
}

resource "random_password" "supabase_s3_key_id" {
  length  = 32
  special = false
  upper   = false
}

resource "random_password" "supabase_s3_access_key" {
  length  = 64
  special = false
  upper   = false
}

locals {
  supabase_jwt_secret  = random_password.supabase_jwt_secret.result
  supabase_anon_key    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzc0MTM0MDAwLCJleHAiOjE5MzE5MDA0MDB9.${random_password.supabase_anon_key_suffix.result}"
  supabase_service_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NzQxMzQwMDAsImV4cCI6MTkzMTkwMDQwMH0.${random_password.supabase_service_key_suffix.result}"

  db_service_name = "supabase-supabase-db" # release.name + "-supabase-db"

  generated_values = {
    secret = {
      jwt = {
        anonKey    = local.supabase_anon_key
        serviceKey = local.supabase_service_key
        secret     = local.supabase_jwt_secret
      }
      db = {
        secretRefKey = {
          password = random_password.supabase_db_password.result
          database = "supabase-pg"
        }
      }
      analytics = {
        publicAccessToken  = random_password.supabase_analytics_public_token.result
        privateAccessToken = random_password.supabase_analytics_private_token.result
      }
      dashboard = {
        username = "admin"
        password = "admin"
      }
      s3 = {
        keyId     = random_password.supabase_s3_key_id.result
        accessKey = random_password.supabase_s3_access_key.result
      }
      realtime = {
        secretKeyBase = random_password.supabase_realtime_secret_key_base.result
      }
      meta = {
        secretRefRef = {
          cryptoKey = random_password.supabase_meta_crypto_key.result
        }
      }
      minio = {
        user     = "supa-storage"
        password = random_password.supabase_minio_password.result
      }
    }

    persistence = {
      db = {
        storageClassName = var.storage_class
        size             = var.persistence_db_size
      }
      storage = {
        storageClassName = var.storage_class
        size             = var.persistence_db_size
      }
      minio = {
        storageClassName = var.storage_class
        size             = var.persistence_minio_size
      }
      imgproxy = {
        storageClassName = var.storage_class
        size             = var.persistence_size
      }
      functions = {
        storageClassName = var.storage_class
        size             = var.persistence_size
      }
      snippets = {
        storageClassName = var.storage_class
        size             = var.persistence_size
      }
      deno = {
        storageClassName = var.storage_class
        size             = var.persistence_size
      }
    }

    environment = {
      auth = {
        GOTRUE_SMTP_ADMIN_EMAIL = var.smtp_user
        GOTRUE_SITE_URL = "https://${var.domain}"
        GOTRUE_JWT_SECRET = local.supabase_jwt_secret
        GOTRUE_SMTP_HOST  = var.smtp_host
        GOTRUE_SMTP_PORT  = var.smtp_port
      }
      studio = {
        # Base settings
        SUPABASE_PUBLIC_URL = "https://${var.domain}"
        SUPABASE_URL        = "https://${var.domain}"
        NEXT_PUBLIC_ENABLE_LOGS = true
        NEXT_ANALYTICS_BACKEND_PROVIDER = "postgres"

        POSTGRES_HOST      = local.db_service_name
        POSTGRES_PORT      = "5432"
        POSTGRES_DB        = "supabase-pg"
        POSTGRES_PASSWORD  = random_password.supabase_db_password.result
        PG_META_CRYPTO_KEY = random_password.supabase_meta_crypto_key.result
      }
    }

    ingress = {
      enabled = true
      annotations = merge(var.k8s_ingress_annotations, {
        "cert-manager.io/cluster-issuer" = var.cert_manager_cluster_issuer
      })
      class = var.k8s_ingress_class
      tls = [
        {
          secretName = "${var.domain}-tls"
          hosts      = [var.domain]
        }
      ]
      hosts = [
        {
          host = "${var.domain}"
          paths = [
            {
              path     = "/"
              pathType = "Prefix"
            }
          ]
        }
      ]
    }

    imgproxy = {
      persistence = {
        enabled          = true
        storageClassName = var.storage_class
        size             = var.persistence_size
      }
    }
  }
}

resource "helm_release" "supabase" {
  name      = "supabase"
  namespace = kubernetes_namespace_v1.supabase.metadata[0].name

  repository = "https://supabase-community.github.io/supabase-kubernetes"
  chart      = "supabase"
  version    = var.chart_version

  timeout          = 180
  wait_for_jobs    = true
  atomic           = true
  take_ownership = true
  upgrade_install  = true
  create_namespace = false

  values = [
    yamlencode(local.generated_values)
  ]
}

output "supabase_database_password" {
  value = random_password.supabase_db_password
}

output "supabase_database_user" {
  value = random_password.supabase_db_user
}

output "supabase_db_service_name" {
  value = local.db_service_name
}

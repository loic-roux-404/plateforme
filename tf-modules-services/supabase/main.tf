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

resource "random_password" "supabase_dashboard_username" {
  length  = 12
  special = false
}

resource "random_password" "supabase_dashboard_password" {
  length  = 24
  special = true
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
        # direct values: `secretRefKey` is a *key-name remapping* map for
        # existing secrets (secretRef), not where the value goes
        password = random_password.supabase_db_password.result
        database = "supabase-pg"
      }
      analytics = {
        publicAccessToken  = random_password.supabase_analytics_public_token.result
        privateAccessToken = random_password.supabase_analytics_private_token.result
      }
      # the auth deployment reads SMTP credentials from this secret, not from
      # environment.auth
      smtp = {
        username = var.smtp_user
        password = var.smtp_pass
      }
      dashboard = {
        username = random_password.supabase_dashboard_username.result
        password = random_password.supabase_dashboard_password.result
      }
      s3 = {
        keyId     = random_password.supabase_s3_key_id.result
        accessKey = random_password.supabase_s3_access_key.result
      }
      realtime = {
        secretKeyBase = random_password.supabase_realtime_secret_key_base.result
      }
      meta = {
        cryptoKey = random_password.supabase_meta_crypto_key.result
      }
      minio = {
        user     = "supa-storage"
        password = random_password.supabase_minio_password.result
      }
    }

    persistence = {
      # a fresh ext4 volume contains lost+found, so the chart's "volume empty"
      # check skips seeding /etc/postgresql-custom and postgres dies on missing
      # config files — use the image's baked config instead
      pgsodium = {
        enabled = false
      }
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
      # chart >=0.8 renders env as a list of {name, value} maps (0.5.x took maps)
      # and our list REPLACES the chart defaults wholesale — so the baseline
      # below mirrors environment.auth from the chart's values.yaml. Missing
      # API_EXTERNAL_URL makes GoTrue exit fatally.
      auth = [
        for k, v in merge(
          {
            API_EXTERNAL_URL                        = "https://${var.domain}"
            GOTRUE_API_HOST                         = "0.0.0.0"
            GOTRUE_API_PORT                         = "9999"
            GOTRUE_SITE_URL                         = "https://${var.domain}"
            GOTRUE_DISABLE_SIGNUP                   = "false"
            GOTRUE_JWT_DEFAULT_GROUP_NAME           = "authenticated"
            GOTRUE_JWT_ADMIN_ROLES                  = "service_role"
            GOTRUE_JWT_AUD                          = "authenticated"
            GOTRUE_JWT_EXP                          = "3600"
            GOTRUE_EXTERNAL_EMAIL_ENABLED           = "true"
            GOTRUE_MAILER_AUTOCONFIRM               = "true"
            GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED = "false"
            GOTRUE_SMTP_ADMIN_EMAIL                 = var.smtp_user
            GOTRUE_SMTP_HOST                        = var.smtp_host
            GOTRUE_SMTP_PORT                        = tostring(var.smtp_port)
            GOTRUE_EXTERNAL_PHONE_ENABLED           = "false"
            GOTRUE_SMS_AUTOCONFIRM                  = "false"
            GOTRUE_SMTP_SENDER_NAME                 = "noreply"
            GOTRUE_MAILER_URLPATHS_INVITE           = "/auth/v1/verify"
            GOTRUE_MAILER_URLPATHS_CONFIRMATION     = "/auth/v1/verify"
            GOTRUE_MAILER_URLPATHS_RECOVERY         = "/auth/v1/verify"
            GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE     = "/auth/v1/verify"
          },
          # GOTRUE_JWT_SECRET / GOTRUE_SMTP_{USER,PASS} / DB_* are hardcoded in
          # the auth template (from secret.*) — repeating them duplicates env
          # keys and the apiserver rejects the deployment
          {
            # Explicit origin globs the GoTrue redirect policy accepts. The module
            # always allows the app's own origin first, then any extra origins.
            GOTRUE_URI_ALLOW_LIST = join(",", concat(["https://${var.domain}/**"], var.github_redirect_allow_list))
            # Explicit origin globs the GoTrue redirect policy accepts. The module
            # always allows the app's own origin first, then any extra origins.
            GOTRUE_URI_ALLOW_LIST = join(",", concat(["https://${var.domain}/**"], var.github_redirect_allow_list))
          },
          var.github_oauth_enabled ? {
            GOTRUE_EXTERNAL_GITHUB_ENABLED      = "true"
            GOTRUE_EXTERNAL_GITHUB_CLIENT_ID    = var.github_client_id
            GOTRUE_EXTERNAL_GITHUB_SECRET       = var.github_client_secret
            GOTRUE_EXTERNAL_GITHUB_REDIRECT_URI = "https://${var.domain}/auth/v1/callback"
            } : {
            GOTRUE_EXTERNAL_GITHUB_ENABLED = "false"
          }
        ) : { name = k, value = tostring(v) }
      ]
      # the studio deployment template already renders SUPABASE_URL,
      # STUDIO_PG_META_URL, POSTGRES_{HOST,PORT,DB,PASSWORD}, PG_META_CRYPTO_KEY
      # and OPENAI_API_KEY itself — listing them here duplicates the env keys
      # and the apiserver rejects the deployment
      studio = [
        for k, v in {
          SUPABASE_PUBLIC_URL             = "https://${var.domain}"
          NEXT_PUBLIC_ENABLE_LOGS         = true
          NEXT_ANALYTICS_BACKEND_PROVIDER = "postgres"
        } : { name = k, value = tostring(v) }
      ]
    }

    # chart bug: init-pgsodium always mounts the pgsodium volume, even with
    # persistence.pgsodium disabled (-> invalid pod). Supply an emptyDir under
    # that name: the init container then seeds it from the image and the main
    # container uses the image's baked /etc/postgresql-custom.
    deployment = {
      db = {
        volumes = [
          {
            name     = "pgsodium"
            emptyDir = {}
          }
        ]
      }
    }

    ingress = {
      enabled = true
      annotations = {
        "cert-manager.io/cluster-issuer" = var.cert_manager_cluster_issuer
      }
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

  timeout          = 900 # 61 resources / ~12 pods: cold image pulls exceed 300s
  wait_for_jobs    = true
  atomic           = true
  take_ownership   = true
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

output "supabase_dashboard_username" {
  description = "Supabase Studio (Kong basic-auth) username"
  value       = random_password.supabase_dashboard_username.result
  sensitive   = true
}

output "supabase_dashboard_password" {
  description = "Supabase Studio (Kong basic-auth) password"
  value       = random_password.supabase_dashboard_password.result
  sensitive   = true
}

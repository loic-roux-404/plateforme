

resource "random_string" "creds_key" {
  length  = 64
  special = false
}

resource "random_string" "creds_iv" {
  length  = 32
  special = false
}

resource "random_string" "jwt_secret" {
  length  = 64
  special = false
}

resource "random_string" "jwt_refresh_secret" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "librechat" {
  metadata {
    name      = "librechat"
    namespace = "default"
  }
  
  data = {
    CREDS_KEY              = "${random_string.creds_key.result}"
    CREDS_IV               = "${random_string.creds_iv.result}"
    MONGO_URI              = "${helm_release.mongodb.output.mongodb_uri}"
    JWT_SECRET             = "${random_string.jwt_secret.result}"
    JWT_REFRESH_SECRET     = "${random_string.jwt_refresh_secret.result}"
  }
}

resource "helm_release" "librechat" {
  name       = "librechat"
  chart      = "<path-to-librechat-helm-chart>"  # Path to the LibreChat chart.
  namespace  = "default"


  values = [
    yamlencode({
      config = {
        env_secrets = {
          secret_ref = kubernetes_secret.librechat.metadata[0].name
        }
      }

      env = {
        ALLOW_EMAIL_LOGIN         = true
        ALLOW_REGISTRATION        = true
        ALLOW_SOCIAL_LOGIN        = false
        ALLOW_SOCIAL_REGISTRATION = false
        CUSTOM_FOOTER             = "Orga-404 librechat"
        DEBUG_CONSOLE             = true
        DEBUG_LOGGING             = true
        DEBUG_OPENAI              = true
        DEBUG_PLUGINS             = true
        DOMAIN_CLIENT             = ""
        DOMAIN_SERVER             = ""
        ENDPOINTS                 = "openAI,azureOpenAI,bingAI,chatGPTBrowser,google,gptPlugins,anthropic"
        MONGO_URI                 = "mongodb://${var.mongo_user}:${var.mongo_password}@${var.mongo_host}:${var.mongo_port}/${var.mongo_database}"
      }
    })
  ]
}


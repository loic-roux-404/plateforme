resource "kubernetes_namespace_v1" "smtp_relay" {
  metadata {
    name = var.namespace
  }
}

locals {
  smtp_values = {
    replicaCount = 1

    config = {
      general = merge(
        {
          ALLOWED_SENDER_DOMAINS = join(" ", var.allowed_sender_domains)
        },
      )

      postfix = merge(
        {
          RELAYHOST                     = var.relay_host
          RELAYHOST_USERNAME            = var.relay_username
          POSTFIX_smtp_tls_security_level = var.relay_tls_security_level
        },
        var.config_postfix_overrides
      )
    }

    # Persistence for postfix queue
    persistence = {
      enabled       = true
      accessModes   = ["ReadWriteOnce"]
      size          = var.persistence_size
      storageClass  = var.persistence_storage_class
    }

    # Restart pods on each upgrade as recommended
    recreateOnRedeploy = true
  }
}

resource "helm_release" "smtp_relay" {
  name       = "smtp-relay"
  namespace  = kubernetes_namespace_v1.smtp_relay.metadata[0].name

  repository = "https://bokysan.github.io/docker-postfix"
  chart      = "mail"
  version    = var.chart_version

  timeout          = 120
  wait_for_jobs    = true
    atomic           = true
  take_ownership = true

  set_sensitive = [{
    name  = "secret.RELAYHOST_PASSWORD"
    value = var.relay_password
  }]

  values = [
    yamlencode(local.smtp_values)
  ]
}

data "kubernetes_service_v1" "smtp" {
  metadata {
    name      = "${helm_release.smtp_relay.name}-mail"
    namespace = helm_release.smtp_relay.namespace
  }
}

output "smtp_infos" {
  depends_on = [ helm_release.smtp_relay ]
  value = {
    host = data.kubernetes_service_v1.smtp.metadata[0].name
    port = data.kubernetes_service_v1.smtp.spec[0].port[0].port
  }
}

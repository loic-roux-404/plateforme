resource "kubernetes_namespace_v1" "listmonk" {
  metadata {
    name = var.namespace
  }
}

module "gotrue_postgres" {
  source              = "../postgres"
  postgres_db         = "listmonk"
  postgres_user       = "listmonk"
  postgres_service_name = "listmonk-postgres"
  postgres_namespace  = kubernetes_namespace_v1.listmonk.metadata[0].name
}

locals {
  generated_values = {
    replicaCount = 1

    postgresql = {
      enable = false
    }

    database = {
      create      = false
      init        = true
      upgrade     = false
      instance_id = "shared"
      host        = "${module.gotrue_postgres.postgres_service_name}.${var.namespace}.svc.cluster.local"
      name        = "${module.gotrue_postgres.postgres_db}"
      username    = "${module.gotrue_postgres.postgres_user}"
    }

    env = {
      private = {
        LISTMONK_app__admin_password = ""
      }
      public = {
        LISTMONK_app__admin_username = ""
        LISTMONK_app__address: "0.0.0.0:9090"
        LISTMONK_smtp__main__host = var.listmonk_smtp_main_host
        LISTMONK_smtp__main__username = var.listmonk_smtp_main_username
      }
    }

    ingress = {
      enabled    = true
      className  = var.k8s_ingress_class
      annotations = merge({
          "kubernetes.io/ingress.class"                    = var.k8s_ingress_class
          "cert-manager.io/cluster-issuer"                 = var.cert_manager_cluster_issuer
          "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
          "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
        }, var.ingress_annotations)
      hosts = [
        {
          host  = var.domain
          paths = [
            {
              path     = "/"
              pathType = "ImplementationSpecific"
            }
          ]
        }
      ],
      tls = [
        {
          secretName = "listmonk-tls"
          hosts      = [var.domain]
        }
      ]
    }
  }
}

resource "helm_release" "listmonk" {
  name       = "listmonk"
  namespace  = var.namespace

  repository = "oci://ghcr.io/deliveryhero/helm-charts"
  chart      = "listmonk"
  version    = var.chart_version
  timeout          = 120
  wait_for_jobs    = true
    atomic           = true
  take_ownership = true
  upgrade_install = true
  

  set_sensitive = [{
    name = "env.private.LISTMONK_smtp__main__password"
    value = var.listmonk_smtp_main_password,
  }, {
    name = "database.password", 
    value = module.gotrue_postgres.postgres_password
  }]

  values = [
    yamlencode(local.generated_values)
  ]
}

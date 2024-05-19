data "kubernetes_namespace" "waypoint_namespace" {
  metadata {
    name = "default"
  }
}

locals {
  namespace = data.kubernetes_namespace.waypoint_namespace.metadata.0.name
  waypoint_manifest_values = templatefile("${path.module}/values.yaml.tmpl", {
    waypoint_namespace           = local.namespace,
    paas_hostname                = var.paas_hostname,
    k8s_ingress_class            = var.k8s_ingress_class
    waypoint_extra_volume_mounts = var.waypoint_extra_volume_mounts
    waypoint_extra_volumes       = var.waypoint_extra_volumes
    cert_manager_cluster_issuer  = var.cert_manager_cluster_issuer
  })
}

resource "helm_release" "waypoint" {
  name          = "waypoint"
  repository    = "https://helm.releases.hashicorp.com"
  chart         = "waypoint"
  version       = "0.1.21"
  namespace     = local.namespace
  values        = [local.waypoint_manifest_values]
  wait_for_jobs = true
  wait          = true

  set {
    name  = "targetNamespace"
    value = local.namespace
  }
}

data "kubernetes_secret" "waypoint_token" {
  depends_on = [helm_release.waypoint]
  metadata {
    name      = "waypoint-server-token"
    namespace = local.namespace
  }
}

resource "kubernetes_ingress_v1" "example" {
  metadata {
    name      = "waypoint-grpc"
    namespace = "default"
    
    annotations = {
      "kubernetes.io/ingress.class"                    = var.k8s_ingress_class
      "nginx.ingress.kubernetes.io/backend-protocol"   = "GRPCS"
      "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
      "nginx.ingress.kubernetes.io/grpc-backend"       = "true"
      "cert-manager.io/cluster-issuer"                 = "letsencrypt-acme-issuer"
    }
  }

  spec {
    rule {
      host = "${var.paas_hostname}"

      http {
        path {
          path     = "/hashicorp.waypoint.Waypoint/"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "waypoint-server"
              port {
                name = "grpc"
              } 
            }
          }
        }

        path {
          path     = "/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = "waypoint-server"
              port {
                name = "grpc"
              } 
            }
          }
        }
      }
    }

    tls {
      hosts = [
        "${var.paas_hostname}"
      ]
      secret_name = "${var.paas_hostname}-tls"
    }
  }
}

output "token" {
  sensitive = true
  value     = data.kubernetes_secret.waypoint_token.data.token
}

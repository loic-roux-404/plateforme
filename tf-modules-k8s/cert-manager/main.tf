resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = var.cert_manager_namespace
  }
}

resource "helm_release" "cert_manager" {
  name          = "cert-manager"
  namespace     = kubernetes_namespace.cert-manager.metadata.0.name
  repository    = "https://charts.jetstack.io"
  chart         = "cert-manager"
  version       = "1.14.4"
  wait_for_jobs = true
  wait          = true

  set {
    name  = "installCRDs"
    value = false
  }
}

resource "kubernetes_manifest" "issuer" {
  depends_on = [helm_release.cert_manager]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-acme-issuer"
    }
    spec = {
      acme = {
        skipTLSVerify = var.letsencrypt_env != "prod"
        email         = var.cert_manager_email
        server        = var.cert_manager_acme_url
        privateKeySecretRef = {
          name = "letsencrypt-acme-priv-key"
        }
        solvers = [
          {
            selector = {}
            http01 = {
              ingress = {
                class = var.k8s_ingress_class
              }
            }
          }
        ]
      }
    }
  }
}

resource "helm_release" "reflector" {
  name          = "reflector"
  namespace     = kubernetes_namespace.cert-manager.metadata.0.name
  repository    = "https://emberstack.github.io/helm-charts"
  chart         = "reflector"
  version       = "7.1.262"
  wait_for_jobs = true
  wait          = true

  set {
    name  = "targetNamespace"
    value = kubernetes_namespace.cert-manager.metadata.0.name
  }

}

resource "kubernetes_config_map" "acme_internal_root_ca" {
  count = var.letsencrypt_env == "local" ? 1 : 0
  metadata {
    name      = "acme-internal-root-ca"
    namespace = kubernetes_namespace.cert-manager.metadata.0.name
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = "true"
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = "true"
    }
  }

  data = {
    "ca.crt" = indent(4, var.internal_acme_ca_content)
  }
}

locals {
  root_ca_config_map = kubernetes_config_map.acme_internal_root_ca.0.metadata[0].name
}

output "issuer" {
  value = kubernetes_manifest.issuer.object.metadata.name
}

output "reflector_metadata_name" {
  value = helm_release.reflector.metadata.0.name
}

output "root_ca_config_map_volume" {
  value = local.root_ca_config_map != null ? [{
    name = local.root_ca_config_map
    configMap = {
      name = local.root_ca_config_map
    }
  }] : []
}

output "root_ca_config_map_volume_mounts" {
  value = local.root_ca_config_map != null ? [{
    name      = local.root_ca_config_map
    mountPath = "/etc/ssl/certs/ca.crt"
    subPath   = "ca.crt"
    readOnly  = true
  }] : []
}

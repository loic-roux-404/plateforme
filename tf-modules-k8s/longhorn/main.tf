resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = "1.11.1"
  namespace        = "longhorn-system"
  create_namespace = true

  values = [
    yamlencode({
      defaultSettings = {
        defaultReplicaCount = 1
      }
      persistence = {
        defaultClassReplicaCount = 1
      }
      ingress = {
        enabled = true
        host    = "longhorn.${var.paas_base_domain}"
        annotations = {
          "kubernetes.io/ingress.class" = var.k8s_ingress_class
          "cert-manager.io/cluster-issuer" = var.cert_manager_cluster_issuer
        }
        tls = [{
          secretName = "longhorn-${var.paas_base_domain}-tls"
          hosts      = ["longhorn.${var.paas_base_domain}"]
        }]
      }
    })
  ]
}


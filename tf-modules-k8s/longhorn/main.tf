resource "kubernetes_namespace_v1" "longhorn" {
  metadata {
    name = "longhorn"
  }
}

resource "kubernetes_secret_v1" "longhorn_s3_credentials" {
  metadata {
    name      = "longhorn-s3-credentials"
    namespace = kubernetes_namespace_v1.longhorn.metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = base64encode(var.object_storage.access_key)
    AWS_SECRET_ACCESS_KEY = base64encode(var.object_storage.access_secret)
  }
}

resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = "1.11.1"
  namespace        = kubernetes_namespace_v1.longhorn.metadata[0].name
  timeout          = 180
  wait_for_jobs    = true
  atomic           = true
  take_ownership = true
  create_namespace = false

  values = [
    yamlencode({
      defaultSettings = {
        defaultReplicaCount         = var.longhorn_default_replica_count
        backupTarget                = "s3://${var.object_storage.s3_url}"
        backupTargetCredentialSecret = kubernetes_secret_v1.longhorn_s3_credentials.metadata[0].name
        deletingConfirmationFlag     = true
      }
      persistence = {
        defaultClassReplicaCount = var.longhorn_default_replica_count
      }
      csi = {
        attacherReplicaCount    = var.longhorn_csi_replicas.attacher
        provisionerReplicaCount = var.longhorn_csi_replicas.provisioner
        resizerReplicaCount     = var.longhorn_csi_replicas.resizer
        snapshotterReplicaCount = var.longhorn_csi_replicas.snapshotter
      }
      longhornUI = {
        replicas = var.longhorn_ui_replicas
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


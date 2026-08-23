resource "kubernetes_namespace_v1" "longhorn" {
  metadata {
    name = "longhorn-system"
  }
}

# Backup target credential secret (AWS_* keys, consumed via env vars by Longhorn):
# https://longhorn.io/docs/latest/snapshots-and-backups/backup-and-restore/set-backup-target/
resource "kubernetes_secret_v1" "longhorn_s3_credentials" {
  metadata {
    name      = "longhorn-s3-credentials"
    namespace = kubernetes_namespace_v1.longhorn.metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.object_storage.access_key
    AWS_SECRET_ACCESS_KEY = var.object_storage.secret_key
    AWS_ENDPOINTS         = trimsuffix(var.object_storage.s3_url, "/")
  }
}

resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = "1.11.1"
  namespace        = kubernetes_namespace_v1.longhorn.metadata[0].name
  timeout          = 900
  wait_for_jobs    = true
  atomic           = true
  take_ownership   = true
  create_namespace = false

  values = [
    yamlencode({
      defaultSettings = {
        defaultReplicaCount      = var.longhorn_default_replica_count
        deletingConfirmationFlag = true
      }
      # In Longhorn 1.11+ the backup target is a BackupTarget CRD seeded from
      # this ConfigMap by longhorn-manager, not a defaultSettings entry.
      defaultBackupStore = {
        backupTarget                 = "s3://${var.backup_bucket}@${var.object_storage.region}/"
        backupTargetCredentialSecret = kubernetes_secret_v1.longhorn_s3_credentials.metadata[0].name
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
        enabled          = true
        ingressClassName = var.k8s_ingress_class
        host             = "longhorn.${var.paas_base_domain}"
        tls              = true
        tlsSecret        = "longhorn-${replace(var.paas_base_domain, ".", "-")}-tls"
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cert_manager_cluster_issuer
        }
      }
    })
  ]
}


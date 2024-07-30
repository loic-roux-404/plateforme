resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "metrics-server"
  version    = var.metrics_server_version
  namespace = "kube-system"
  atomic = true
  timeout = 60

  values = [
    yamlencode({
      rbac = {
        create = true
      }
      replicas = 1
      resourcesPreset = "nano"
      apiService = {
        create = false
        insecureSkipTLSVerify = var.insecure_skip_tls_verify
      }
    })
  ]
}

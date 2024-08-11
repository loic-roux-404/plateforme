resource "helm_release" "cert_manager" {
  name          = "cert-manager"
  namespace     = var.cert_manager_namespace
  create_namespace = true
  repository    = "https://charts.jetstack.io"
  chart         = "cert-manager"
  version       = "1.15.2"
  wait_for_jobs = true
  atomic = true
  timeout = 120

  set {
    name  = "crds.enabled"
    value = true
  } 
}

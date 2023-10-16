resource "helm_release" "ingress-nginx" {
  repository = "https://kubernetes.github.io/ingress-nginx"
  name       = "ingress-nginx"
  namespace  = "kube-system"
  chart      = "ingress-nginx"
  timeout    = 600
  wait_for_jobs = true
  wait          = true
  values = [
    yamlencode({
      fullnameOverride = "ingress-nginx"
      controller = {
        useComponentLabel = true
        admissionWebhooks = {
          enabled : false
        }
        ingressClass = "nginx"
        extraArgs = {
          "enable-ssl-passthrough" = "true"
        }
        publishService = {
          enabled = true
        }
      }
    })
  ]
}

data "kubernetes_service" "ingress_service" {
  depends_on = [ helm_release.ingress-nginx ]
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "kube-system"
  }
}

output "ingress_controller_ip" {
  value = data.kubernetes_service.ingress_service.status.0.load_balancer.0.ingress.0.ip
}

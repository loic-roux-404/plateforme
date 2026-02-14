data "kubernetes_service" "ingress" {
  metadata {
    name      = "rke2-ingress-nginx"
    namespace = "Kube-system"
  }
}

output "ingress_service" {
  value = data.kubernetes_service.ingress
}

output "ingress_controller_ip" {
  value = data.kubernetes_service.ingress.status.0.load_balancer.0.ingress.0.ip
}

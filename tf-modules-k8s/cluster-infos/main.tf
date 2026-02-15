data "kubernetes_resources" "ingress_nginx_pod" {
  api_version = "v1"
  kind        = "Pod"
  namespace   = "kube-system"
  label_selector = "app.kubernetes.io/instance=${var.label_selector}"
}

output "ingress_controller_ip" {
  value = try(data.kubernetes_resources.ingress_nginx_pod.objects[0].status.hostIP, null)
  description = "Host IP of the ingress-nginx controller pod"
}

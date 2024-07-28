
resource "kubernetes_namespace"  "cilium-secrets" {
  metadata {
    name = "cilium-secrets"
  }
}

resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  atomic = true
  wait_for_jobs = true
  create_namespace = true

  values = [
    yamlencode({
      tag                      = "v${var.cilium_version}"
      containerRuntime = {
        integration = "containerd"
        socketPath  = "/var/run/k3s/containerd/containerd.sock"
      }
      kubeProxyReplacement = true
      bpf = {
        masquerade = true
      }
      k8sServiceHost = var.k8s_endpoint
      k8sServicePort = var.k8s_port
      "ipam.operator.clusterPoolIPv4PodCIDRList" = "10.42.0.0/16"
      ingressController = {
        enabled = true
        default = true
      }
      "prometheus.enabled" = true
      "operator.prometheus.enabled=true" = true
      "hubble.metrics.enabled" = true
    })
  ]
}


data "kubernetes_service" "ingress" {
  metadata {
    name      = "cilium"
    namespace = "kube-system"
  }

  depends_on = [helm_release.cilium]
}

output "ingress_service" {
  value = data.kubernetes_service.ingress
}

output "ingress_controller_ip" {
  value = data.kubernetes_service.ingress.status.0.load_balancer.0.ingress.0.ip
}

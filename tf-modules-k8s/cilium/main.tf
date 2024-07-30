data "kubernetes_nodes" "selected" {
  metadata {
    labels = {
      "kubernetes.io/hostname" = var.node_name
    }
  }
}

locals {
  node_internal_ip = [
    for addr in data.kubernetes_nodes.selected.nodes[0].status[0].addresses :
    addr.address if addr.type == "InternalIP"
  ][0]
}

resource "helm_release" "cilium" {
  name          = "cilium"
  namespace     = var.cilium_namespace
  repository    = "https://helm.cilium.io"
  chart         = "cilium"
  version       = var.cilium_version
  atomic        = true
  wait_for_jobs = true
  timeout       = 180
  create_namespace = true

  values = [
    yamlencode(merge(var.cilium_helm_values, {
      k8sServiceHost = local.node_internal_ip
      k8sServicePort = var.k3s_port
      ipam = {
        operator = {
          clusterPoolIPv4PodCIDRList = data.kubernetes_nodes.selected.nodes[0].spec[0].pod_cidrs
          clusterPoolIPv6PodCIDRList = data.kubernetes_nodes.selected.nodes[0].spec[0].pod_cidrs
        }
      }
    }))
  ]
}

data "kubernetes_namespace" "cilium" {
  depends_on = [ helm_release.cilium ]
  metadata {
    name = var.cilium_namespace
  }
}

data "kubernetes_service" "ingress" {
  metadata {
    name      = "cilium-ingress"
    namespace = data.kubernetes_namespace.cilium.metadata[0].name
  }

  depends_on = [helm_release.cilium]
}

output "ingress_service" {
  value = data.kubernetes_service.ingress
}

output "ingress_controller_ip" {
  value = data.kubernetes_service.ingress.status.0.load_balancer.0.ingress.0.ip
}

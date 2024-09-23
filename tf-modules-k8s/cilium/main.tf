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
  node_external_ip = [
    for addr in data.kubernetes_nodes.selected.nodes[0].status[0].addresses :
    addr.address if addr.type == "ExternalIP"
  ][0]
}

resource "kubernetes_manifest" "cilium_lb_ipam_external" {
  depends_on = [helm_release.cilium]
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name = "cilium-lb-ipam-external"
    }
    spec = {
      blocks = length(var.external_blocks) > 0 ? var.external_blocks : [
        {
          cidr  = null
          start = local.node_external_ip
          stop  = local.node_external_ip
        }
      ]
      serviceSelector = {
        matchLabels = {
          "kube-paas/external" = "true"
          "wait-for-it"        = helm_release.cilium.metadata[0].name
        }
      }
    }
  }
}

resource "kubernetes_manifest" "cilium_lb_ipam_internal" {
  depends_on = [helm_release.cilium]
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name = "cilium-lb-ipam-internal"
    }
    spec = {
      blocks = length(var.external_blocks) > 0 ? var.internal_blocks : [
        {
          cidr  = null
          start = local.node_internal_ip
          stop  = local.node_internal_ip
        }
      ]
      serviceSelector = {
        matchLabels = {
          "kube-paas/internal" = "true"
        }
      }
    }
  }
}

resource "kubernetes_service" "cilium_ingress_external" {
  depends_on = [ kubernetes_manifest.cilium_lb_ipam_external ]
  metadata {
    name      = "cilium-ingress-external"
    namespace = helm_release.cilium.metadata[0].namespace
    labels = {
      "cilium.io/ingress" = "true"
      "kube-paas/external" = "true"
    }
  }

  spec {
    type                    = "LoadBalancer"
    external_traffic_policy = "Cluster"
    internal_traffic_policy = "Cluster"
    session_affinity        = "None"

    ip_family_policy = "SingleStack"
    ip_families      = ["IPv4"]

    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = 80
    }

    port {
      name        = "https"
      port        = 443
      protocol    = "TCP"
      target_port = 443
    }
  }
}

data "kubernetes_namespace" "cilium" {
  metadata {
    name = helm_release.cilium.metadata[0].namespace
  }
}

data "kubernetes_service" "ingress" {
  metadata {
    name      = "cilium-ingress-internal"
    namespace = helm_release.cilium.metadata[0].namespace
  }
}

output "ingress_service" {
  value = data.kubernetes_service.ingress
}

output "ingress_controller_ip" {
  value = data.kubernetes_service.ingress.status.0.load_balancer.0.ingress.0.ip
}

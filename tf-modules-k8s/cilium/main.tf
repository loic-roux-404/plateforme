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

resource "helm_release" "cilium" {
  name             = "cilium"
  namespace        = var.cilium_namespace
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  version          = var.cilium_version
  atomic           = true
  wait_for_jobs    = true
  timeout          = 180
  create_namespace = true

  values = [
    yamlencode(merge({
      global = {}
      ipam   = {}
      cluster = {
        name = var.node_name
      }
      ingressController = {
        service : {
          labels : { "k3s-paas/internal" : "true" }
        }
      }
      k8sServiceHost = var.k3s_host
      k8sServicePort = local.node_internal_ip
      ipam = {
        operator = {
          clusterPoolIPv4PodCIDRList = data.kubernetes_nodes.selected.nodes[0].spec[0].pod_cidrs
        }
      }
    }, var.cilium_helm_values))
  ]
}

resource "kubernetes_manifest" "cilium_lb_ipam" {
  depends_on = [helm_release.cilium]
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name      = "cilium-lb-ipam-external"
      namespace = var.cilium_namespace
    }
    spec = {
      blocks = length(var.external_blocks) > 0 ? var.external_blocks : [
        {
          start = node_external_ip
          end   = node_external_ip
        }
      ]
      serviceSelector = {
        matchLabels = {
          "k3s-paas/external" = "true"
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
      name      = "cilium-lb-ipam-internal"
      namespace = var.cilium_namespace
    }
    spec = {
      blocks = length(var.external_blocks) > 0 ? var.internal_blocks : [
        {
          start = node_internal_ip
          end   = node_internal_ip
        }
      ]
      serviceSelector = {
        matchLabels = {
          "k3s-paas/internal" = "true"
        }
      }
    }
  }
}

resource "kubernetes_service" "cilium_ingress_external" {
  metadata {
    name      = "cilium-ingress-external"
    namespace = "kube-system"
    labels = {
      "cilium.io/ingress" = "true"
      "k3s-paas/external" = "true"
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
  depends_on = [helm_release.cilium]
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

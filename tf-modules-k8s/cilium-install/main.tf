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
    yamlencode({
      l2announcements = {
        enabled = true
      }
      kubeProxyReplacement = true
      bpf = {
        masquerade          = true
        lbExternalClusterIP = false
      }
      gatewayAPI = {
        enabled = false
      }
      routingMode    = "tunnel"
      tunnelProtocol = "vxlan"
      ingressController = {
        enabled          = true
        default          = true
        loadbalancerMode = "dedicated"
        service = {
          name   = "cilium-ingress-external"
          labels = { "kube-paas/internal" : "true" }
        }
      }
      prometheus = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
      operator = {
        replicas = 1
        prometheus = {
          enabled = true
        }
      }
      hubble = {
        relay = {
          enabled = true
        }
        metrics = {
          enabled = [
            "dns", "drop", "tcp", "flow", "port-distribution", "icmp",
            "httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction"
          ]
          enableOpenMetrics = true
        }
      }

      k8sServiceHost = local.node_internal_ip
      k8sServicePort = var.k3s_port
      ipam = {
        operator = {
          clusterPoolIPv4PodCIDRList = data.kubernetes_nodes.selected.nodes[0].spec[0].pod_cidrs
        }
      }
    })
  ]
}

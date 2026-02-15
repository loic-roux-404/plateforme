locals {
  ingress_hosts_internals_joined = join(" ", var.ingress_hosts_internals)
}

resource "kubernetes_manifest" "rke2_coredns_config" {
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "rke2-coredns"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = yamlencode({
        zoneFiles = [
          # Ingress hosts configuration
          {
            filename = "ingress-hosts.conf"
            domain   = local.ingress_hosts_internals_joined
            contents = <<-EOT
              ${local.ingress_hosts_internals_joined} {
                hosts {
                  ${var.ingress_controller_ip} ${local.ingress_hosts_internals_joined}
                  fallthrough
                }
                whoami
              }
            EOT
          }
        ]
        extraConfig = {
          import = {
            parameters ="/etc/coredns/*.conf"
          }
        }
      })
    }
  }
}

resource "time_static" "restarted_at" {}

resource "kubernetes_annotations" "coredns" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "rke2-coredns-rke2-coredns"
    namespace = "kube-system"
  }
  template_annotations = {
    "kubectl.kubernetes.io/restartedAt" = time_static.restarted_at.rfc3339
  }
}

output "coredns_custom_id" {
  value = kubernetes_annotations.coredns.id
}

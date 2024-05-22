locals {
  ingress_hosts_internals_joined = join(" ", var.ingress_hosts_internals)
}

resource "kubernetes_config_map" "coredns-custom" {
  metadata {
    name      = "coredns-custom"
    namespace = "kube-system"
  }

  data = {
    "ingress-hosts.server" = <<EOF
      ${local.ingress_hosts_internals_joined} {
        hosts {
          ${var.ingress_controller_ip} ${local.ingress_hosts_internals_joined}
          fallthrough
        }
        whoami
      }
      EOF

    "acme-internal.server" = <<EOF
      ${var.internal_acme_hostname} {
        hosts {
          ${var.internal_acme_network_ip} ${var.internal_acme_hostname}
          fallthrough
        }
        whoami
      }
      EOF
  }
}

resource "time_static" "restarted_at" {}

resource "kubernetes_annotations" "coredns" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  template_annotations = {
    "kubectl.kubernetes.io/restartedAt" = time_static.restarted_at.rfc3339
  }
}

output "coredns_custom_id" {
  value = kubernetes_annotations.coredns.id
}

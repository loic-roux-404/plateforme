resource "kubernetes_namespace" "metallb_system" {
  metadata {
    name = "metallb-system"
    labels = {
      app = "metallb"
    }
  }
}

data "http" "metallb_manifests_metallb_native" {
  url = var.metallb_manifests_metallb_frr
}

resource "kubernetes_manifest" "metallb_manifests_metallb_native" {
  manifest = yamldecode(data.http.metallb_manifests_metallb_native.response_body)
  wait {
    rollout = true
  }
}

data "http" "metallb_manifests_metallb_frr" {
  url = var.metallb_manifests_metallb_frr
}

resource "kubernetes_manifest" "metallb_manifests_metallb_frr" {
  manifest = yamldecode(data.http.metallb_manifests_metallb_frr.response_body)
  wait {
    rollout = true
  }
}

resource "kubernetes_manifest" "metallb_ip_address_pool" {
  depends_on = [ kubernetes_manifest.metallb_manifests_metallb_frr ]
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "kind-pool"
      namespace = "${kubernetes_namespace.metallb_system.metadata.0.name}"
    }
    spec = {
      addresses = [var.metallb_ip_range]
    }
  }
}

resource "kubernetes_manifest" "metallb_l2_advertisement" {
  depends_on = [ kubernetes_manifest.metallb_manifests_metallb_frr ]
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "kind-l2"
      namespace = "${kubernetes_namespace.metallb_system.metadata.0.name}"
    }
  }
}

resource "kubernetes_manifest" "speaker_daemonset" {
  # Assuming that the spect for speaker_daemonset is available in
  # the file 'speaker_daemonset.yaml'
  depends_on = [ kubernetes_manifest.metallb_manifests_metallb_frr ]
  manifest = {
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    namespace  = "${kubernetes_namespace.metallb_system.metadata.0.name}"
    metadata = {
      name = "speaker"
    }
  }

  wait {
    fields = {
      "status.numberAvailable" = 1
    }
  }
}

output "daemonset_state" {
  value = kubernetes_manifest.speaker_daemonset.object
}

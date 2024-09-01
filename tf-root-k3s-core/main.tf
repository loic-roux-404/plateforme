# module "cilium_install" {
#   source = "../tf-modules-k8s/cilium-install"
#   node_name = var.k3s_node_name
#   k3s_host = var.k3s_endpoint
# }

# module "metrics_server_install" {
#   source = "../tf-modules-k8s/metrics-server"
# }

module "cert_manager_install" {
  source = "../tf-modules-k8s/cert-manager-install"
}

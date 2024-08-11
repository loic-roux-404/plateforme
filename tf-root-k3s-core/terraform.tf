provider "kubernetes" {
  host                   = "https://${var.k3s_endpoint}:${var.k3s_port}"
  cluster_ca_certificate = var.k3s_config.cluster_ca_certificate
  client_certificate     = var.k3s_config.client_certificate
  client_key             = var.k3s_config.client_key
}

provider "helm" {
  kubernetes {
    host                   = "https://${var.k3s_endpoint}:${var.k3s_port}"
    cluster_ca_certificate = var.k3s_config.cluster_ca_certificate
    client_certificate     = var.k3s_config.client_certificate
    client_key             = var.k3s_config.client_key
  }
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.29.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.1"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

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

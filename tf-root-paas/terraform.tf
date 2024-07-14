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
  config_path = "~/.kube/config"
  config_context_cluster = var.tailscale_operator_hostname
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["configure", "kubeconfig", var.tailscale_operator_hostname]
    command     = "tailscale"
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

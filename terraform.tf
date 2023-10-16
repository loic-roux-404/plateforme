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
    # contabo = {
    #   source = "contabo/contabo"
    #   version = ">= 0.1.23"
    # }
  }
}

provider "kubernetes" {
  host        = "https://${var.vm_ip}:6443"
  config_path = "~/.kube/config"
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["zizou@localhost", "-p", "2222", "sudo", "cat", "/etc/rancher/k3s/k3s.yaml", ">", "~/.kube/config"]
    command     = "ssh"
  }
}

provider "helm" {
  kubernetes {
    host        = "https://${var.vm_ip}:6443"
    config_path = "~/.kube/config"
  }
}

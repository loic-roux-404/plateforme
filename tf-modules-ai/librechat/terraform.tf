terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    mongodb = {
      source  = "01Joseph-Hwang10/mongodb"
    }
  }
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.1"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Contabo S3-compatible object storage via the AWS provider.
provider "aws" {
  region     = var.object_storage.region
  access_key = var.object_storage.access_key
  secret_key = var.object_storage.secret_key

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  skip_metadata_api_check     = true

  s3_use_path_style = true # Contabo S3 requires path-style, not virtual-hosted

  endpoints {
    s3 = var.object_storage.s3_url
  }
}

provider "kubernetes" {
  host                   = "https://${var.k3s_endpoint}:${var.k3s_port}"
  cluster_ca_certificate = var.k3s_config.cluster_ca_certificate
  client_certificate     = var.k3s_config.client_certificate
  client_key             = var.k3s_config.client_key
}

provider "helm" {
  kubernetes = {
    host                   = "https://${var.k3s_endpoint}:${var.k3s_port}"
    cluster_ca_certificate = var.k3s_config.cluster_ca_certificate
    client_certificate     = var.k3s_config.client_certificate
    client_key             = var.k3s_config.client_key
  }
}

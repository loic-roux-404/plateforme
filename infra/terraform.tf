terraform {

  required_version = ">=0.12"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.31.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
    namedotcom = {
      source  = "lexfrei/namedotcom"
      version = "1.2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

provider "azuread" {
  tenant_id = var.tenant_id
}

provider "github" {
  token = var.github_token
  owner = var.github_organization
}

provider "time" {}

provider "namedotcom" {
  token    = var.namedotcom_token
  username = var.namedotcom_username
}
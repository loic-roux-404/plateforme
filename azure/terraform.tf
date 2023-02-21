terraform {

  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.37"
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

provider "github" {
  token = var.github_token
  owner = var.github_organization
}

provider "namedotcom" {
  token    = var.namedotcom_token
  username = var.namedotcom_username
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

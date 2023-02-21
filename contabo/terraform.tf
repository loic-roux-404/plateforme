terraform {

  required_version = ">=0.12"

  required_providers {
    contabo = {
      source = "contabo/contabo"
      version = ">= 0.1.17"
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

#############################
# Configure Contabo with env vars
# CNTB_OAUTH2_CLIENT_ID
# CNTB_OAUTH2_CLIENT_SECRET
# CNTB_OAUTH2_USER
# CNTB_OAUTH2_PASS
#############################
provider "contabo" {}

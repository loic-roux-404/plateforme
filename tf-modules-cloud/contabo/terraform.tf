terraform {

  required_version = ">=1.4"

  required_providers {
    contabo = {
      source = "loic-roux-404/contabo"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

provider "contabo" {
  oauth2_client_id     = var.contabo_credentials.oauth2_client_id
  oauth2_client_secret = var.contabo_credentials.oauth2_client_secret
  oauth2_user          = var.contabo_credentials.oauth2_user
  oauth2_pass          = var.contabo_credentials.oauth2_pass
}

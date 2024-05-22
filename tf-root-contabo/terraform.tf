terraform {

  required_version = ">=1.4"

  required_providers {
    contabo = {
      source  = "contabo/contabo"
      version = ">= 0.1.23"
    }
    gandi = {
      source = "go-gandi/gandi"
    }
    time = {
      source = "hashicorp/time"
    }
    tailscale = {
      source = "tailscale/tailscale"
    }
  }
}

provider "tailscale" {
  api_key = var.tailscale_api_key
  #tailnet = var.tailscale_tailnet_id
}

provider "gandi" {
  personal_access_token = var.gandi_token
}

provider "contabo" {
  oauth2_client_id     = var.contabo_credentials.oauth2_client_id
  oauth2_client_secret = var.contabo_credentials.oauth2_client_secret
  oauth2_user          = var.contabo_credentials.oauth2_user
  oauth2_pass          = var.contabo_credentials.oauth2_pass
}

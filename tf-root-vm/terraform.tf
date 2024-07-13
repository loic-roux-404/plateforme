terraform {
  required_version = ">=1.4"
  required_providers {
    contabo = {
      source  = "contabo/contabo"
    }
    time = {
      source = "hashicorp/time"
    }
    local = {
      source = "hashicorp/local"
    }
    tailscale = {
      source = "tailscale/tailscale"
    }
    gandi = {
      source = "go-gandi/gandi"
    }
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
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

provider "libvirt" {
  uri = "qemu:///system"
}

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client.id
  oauth_client_secret = var.tailscale_oauth_client.secret
  tailnet             = var.tailscale_tailnet
  scopes              = ["all"]
}


terraform {
  required_version = ">=1.4"
  required_providers {
    contabo = {
      source = "loic-roux-404/contabo"
    }
    time = {
      source = "hashicorp/time"
    }
    local = {
      source = "hashicorp/local"
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

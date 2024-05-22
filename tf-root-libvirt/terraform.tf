terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    healthcheck = {
      source  = "Ferlab-Ste-Justine/healthcheck"
      version = "0.2.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

provider "healthcheck" {
}

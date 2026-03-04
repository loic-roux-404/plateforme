terraform {
  required_version = ">=1.4"
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.8.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

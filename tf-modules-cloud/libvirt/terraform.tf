terraform {
  required_version = ">=1.4"
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

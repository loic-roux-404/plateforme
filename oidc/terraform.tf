terraform {
  required_providers {
    waypoint = {
      source  = "hashicorp-dev-advocates/waypoint"
    }
  }
}

provider "waypoint" {
  waypoint_addr = var.paas_hostname
  token         = var.paas_token
}

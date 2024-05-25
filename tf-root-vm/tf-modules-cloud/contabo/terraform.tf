terraform {

  required_version = ">=1.4"

  required_providers {
    contabo = {
      source  = "contabo/contabo"
      version = ">= 0.1.23"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}


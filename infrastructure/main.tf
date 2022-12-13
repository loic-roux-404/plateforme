terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

variable "client_id" {
  type    = string
  default = ""
}

variable "client_cert_path" {
  type    = string
  default = ""
}

variable "tenant_id" {
  type    = string
  default = ""
}

variable "subscription_id" {
  type    = string
  default = ""
}

variable "resource_group_name" {
  type    = string
  default = "kubeapps-group"
}

provider "azurerm" {
  features {}

  subscription_id   = var.subscription_id
  tenant_id         = var.tenant_id
  client_id         = var.client_id
  client_cert_path  = var.client_cert_path
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "West Europe"
  tags = ["paas"]
}

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

resource "azurerm_resource_group" "paas-group" {
  name     = var.resource_group_name
  location = "West Europe"
  tags = ["paas"]
}
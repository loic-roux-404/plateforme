data "azuread_client_config" "current" {}

data "azurerm_resource_group" "paas" {
  name = "kubeapps-group"
}

data "azurerm_image" "search" {
  name                = "kubeapps-az-arm"
  resource_group_name = data.azurerm_resource_group.paas.name
}

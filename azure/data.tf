data "azurerm_resource_group" "paas" {
  name = "kubeapps-group"
}

data "azurerm_image" "search" {
  name                = "k3s-pre-paas-az-arm"
  resource_group_name = data.azurerm_resource_group.paas.name
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "primary" {}

data "github_organization" "org" {
  name = var.github_organization
}

data "github_membership" "all" {
  for_each = toset(data.github_organization.org.members)
  username = each.value
}

data "github_membership" "all_admin" {
  for_each = {
    for _, member in data.github_membership.all:
    _ => member if member.role == "admin"
  }
  username = each.value.username
}

############
# Accounts
############
resource "github_team" "opsteam" {
  name                      = var.github_team
  description               = "This is the production team"
  privacy                   = "closed"
  create_default_maintainer = true
}

resource "azuread_application" "ad_paas" {
  display_name = "adpaas"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "ad_paas" {
  application_id = azuread_application.ad_paas.application_id
  owners         = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "ad_paas" {
  application_object_id = azuread_application.ad_paas.object_id
  end_date_relative     = "4320h" # expire in 6 months
}

resource "azurerm_role_assignment" "paas" {
  scope                = data.azurerm_resource_group.paas.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.ad_paas.object_id
}

resource "azurerm_role_assignment" "paas_vault" {
  scope                = data.azurerm_resource_group.paas.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azuread_service_principal.ad_paas.object_id
}

provider "azurerm" {
  tenant_id = azuread_service_principal.ad_paas.application_tenant_id
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

############
# Key vault
############
resource "random_id" "kvname" {
  byte_length = 5
  prefix      = "keyvault"
}

resource "azurerm_key_vault" "paas" {
  name                       = random_id.kvname.hex
  location                   = data.azurerm_resource_group.paas.location
  resource_group_name        = data.azurerm_resource_group.paas.name
  soft_delete_retention_days = 7

  tenant_id = azuread_service_principal.ad_paas.application_tenant_id

  enabled_for_disk_encryption = true
  purge_protection_enabled    = false
  enabled_for_deployment      = true

  sku_name = "standard"

  lifecycle {
    create_before_destroy = true
  }

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

resource "azurerm_key_vault_access_policy" "paas" {
  key_vault_id   = azurerm_key_vault.paas.id
  tenant_id      = azuread_service_principal.ad_paas.application_tenant_id
  object_id      = azuread_service_principal.ad_paas.object_id
  application_id = azuread_application.ad_paas.application_id

  key_permissions = [
    "get", "create",
  ]

  secret_permissions = [
    "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
  ]

  storage_permissions = [
    "get",
  ]
}

# Kubeapps OAuth Proxy
resource "random_password" "kubeapps_oauth_proxy_cookie_secret" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Dex oidc client
resource "random_password" "dex_client_id" {
  length  = 16
  special = false
}

resource "random_password" "dex_client_secret" {
  length  = 24
  special = false
}

locals {
  final_secrets = merge(
    var.secrets,
    {
      dex_client_id                      = random_password.dex_client_id.result
      dex_client_secret                  = random_password.dex_client_secret.result
      kubeapps_oauth_proxy_cookie_secret = random_password.kubeapps_oauth_proxy_cookie_secret.result
    }
  )
}

resource "azurerm_key_vault_secret" "paas_all_secrets" {
  for_each     = local.final_secrets
  name         = replace(each.key, "_", "-")
  value        = each.value
  key_vault_id = azurerm_key_vault.paas.id
  depends_on = [
    azurerm_key_vault_access_policy.paas,
  ]
}

############
# Vm Network
############
resource "azurerm_virtual_network" "paas" {
  name                = "paas-vn"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.paas.location
  resource_group_name = data.azurerm_resource_group.paas.name
}

resource "azurerm_subnet" "paas" {
  name                 = "paas-sub"
  resource_group_name  = data.azurerm_resource_group.paas.name
  virtual_network_name = azurerm_virtual_network.paas.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "paas" {
  name                = "paas-security-gp"
  location            = data.azurerm_resource_group.paas.location
  resource_group_name = data.azurerm_resource_group.paas.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.paas.id
  network_security_group_id = azurerm_network_security_group.paas.id
}

resource "azurerm_public_ip" "paas" {
  name                = "paas-ip"
  resource_group_name = data.azurerm_resource_group.paas.name
  location            = data.azurerm_resource_group.paas.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "paas" {
  name                = "paas-nic"
  location            = data.azurerm_resource_group.paas.location
  resource_group_name = data.azurerm_resource_group.paas.name

  enable_accelerated_networking = true

  ip_configuration {
    name                          = "paasconfiguration1"
    subnet_id                     = azurerm_subnet.paas.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.paas.id
  }
}

############
# Vm creation
############
resource "azurerm_virtual_machine" "paas" {
  name                  = "paasvm"
  location              = data.azurerm_resource_group.paas.location
  resource_group_name   = data.azurerm_resource_group.paas.name
  network_interface_ids = [azurerm_network_interface.paas.id]
  vm_size               = "Standard_DS2_v2"

  storage_image_reference {
    id = data.azurerm_image.search.id
  }

  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "paasdisk1"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "StandardSSD_LRS"
  }

  os_profile {
    computer_name  = "paasvm"
    admin_username = "kubeapps"
    admin_password = "Kubeapps12!?"

    custom_data = templatefile(
      "${path.module}/cloud-init.yaml",
      {
        kubeapps_hostname      = "kubeapps.${azurerm_dns_zone.paas.name}"
        dex_hostname           = "dex.${azurerm_dns_zone.paas.name}"
        vault_uri              = azurerm_key_vault.paas.vault_uri
        dex_github_client_org  = github_team.opsteam.name
        dex_github_client_team = var.github_organization
      }
    )
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

############
# Dns
############
resource "azurerm_dns_zone" "paas" {
  name                = var.domain
  resource_group_name = data.azurerm_resource_group.paas.name
}

resource "namedotcom_domain_nameservers" "namedotcom_paas_ns" {
  domain_name = var.domain
  nameservers = [
    # Delete ending dot which isn't valid for namedotcom api
    for item in azurerm_dns_zone.paas.name_servers : trimsuffix(item, ".")
  ]
}

resource "azurerm_dns_a_record" "paas" {
  name                = "*"
  zone_name           = azurerm_dns_zone.paas.name
  resource_group_name = data.azurerm_resource_group.paas.name
  ttl                 = 3600
  target_resource_id  = azurerm_public_ip.paas.id
}

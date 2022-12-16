terraform {

  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Already created resource group
data "azurerm_resource_group" "paas" {
  name = "kubeapps-group"
}

data "azurerm_dns_zone" "paas" {
  name                = "k3s-paas.paastutorialesgi.tech"
  resource_group_name = data.azurerm_resource_group.paas.name
}

resource "azurerm_virtual_network" "paas" {
  name                = "acctvn"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.paas.location
  resource_group_name = data.azurerm_resource_group.paas.name
}

resource "azurerm_subnet" "paas" {
  name                 = "acctsub"
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

  ip_configuration {
    name                          = "paasconfiguration1"
    subnet_id                     = azurerm_subnet.paas.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.paas.id
  }
}

resource "azurerm_dns_a_record" "paas" {
  name                = "*"
  zone_name           = data.azurerm_dns_zone.paas.name
  resource_group_name = data.azurerm_resource_group.paas.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.paas.id
}

data "azurerm_image" "search" {
  name                = "kubeapps-az-arm"
  resource_group_name = data.azurerm_resource_group.paas.name
}

resource "azurerm_virtual_machine" "paas" {
  name                  = "paasvm"
  location              = data.azurerm_resource_group.paas.location
  resource_group_name   = data.azurerm_resource_group.paas.name
  network_interface_ids = [azurerm_network_interface.paas.id]
  vm_size               = "Standard_B2s"

  storage_image_reference {
    id = data.azurerm_image.search.id
  }

  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "paasdisk1"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "paasvm"
    admin_username = "kubeapps"
    admin_password = "Kubeapps12?!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

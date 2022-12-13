#--Custom Image Definition
data "azurerm_image" "tinfoilcompute" {
  name                = "tinfoilubuntu"
  resource_group_name = "tinfoil_images_rg"
}
#--Subnet Definition
data "azurerm_subnet" "tinfoilcompute" {
    name                 = "tinfoil_prod_subnet"
    resource_group_name  = "tinfoil_network_rg"
    virtual_network_name = "tinfoil_vnet"
}
#--NIC
resource "azurerm_network_interface" "tinfoilcompute" {
    name                = "tinfoil_web01-nic"
    location            = "uksouth"
    resource_group_name = "tinfoil_compute_rg"
    ip_configuration {
        name                          = "tinfoil_web01-ipconfig"
        subnet_id                     = data.azurerm_subnet.tinfoilcompute.0.id
        private_ip_address_allocation = "Static"
        private_ip_address            = "10.0.1.13"
    }
    tags = {
        Resource = "Network"
    }
}
#--Virtual Machines
resource "azurerm_virtual_machine" "tinfoilcompute" {
    name                  = "kubeapps-web01-vm"
    location              = "uksouth"
    resource_group_name   = "tinfoil_compute_rg"
    network_interface_ids = ["${element(azurerm_network_interface.tinfoilcompute.*.id, count.index)}"]
    vm_size               = "Standard_b1ls"
    storage_image_reference {
        id = "${data.azurerm_image.tinfoilcompute.id}"
    }
    storage_os_disk {
        name              = "tinfoil_web01_osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }
    os_profile {
        computer_name  = "tinfoil-web01-vm"
        admin_username = "tinfoiladmin"
        admin_password = "Sup3rs3cr3tpa55w0rd!"
    }
    boot_diagnostics {
        enabled        = true
        storage_uri    = var.diagnostic_blob
    }
    os_profile_linux_config {
        disable_password_authentication = false
        ssh_keys {
            path     = "/home/${var.admin_user}/.ssh/authorized_keys"
            key_data = "ssh-rsa AADAQABAAABAQCiMKJfM+pxbRB4vRwCuks4oN3x71YCO8Dm"
        }
    }
    tags = {
        Resource = "Compute"
    }
}
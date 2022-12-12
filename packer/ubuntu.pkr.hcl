variable "client_id" {
  type = string
  default = ""
}

variable "client_secret" {
  type = string
  default = ""
}

variable "tenant_id" {
  type = string
  default = ""
}

variable "subscription_id" {
  type = string
  default = ""
}

variable "resource_group_name" {
  type = string
  default = ""
}

variable "storage_account_name" {
  type = string
  default = ""
}

variable "location" {
  type = string
  default = ""
}

variable "image_name" {
  type = string
  default = ""
}

variable "vm_size" {
  type = string
  default = "Standard_D2s_v3"
}

variable "os_disk_name" {
  type = string
  default = ""
}

variable "admin_username" {
  type = string
  default = ""
}

variable "admin_password" {
  type = string
  default = ""
}

resource "azure-arm" "vm" {
  client_id = var.client_id
  client_secret = var.client_secret
  tenant_id = var.tenant_id
  subscription_id = var.subscription_id
  resource_group_name = var.resource_group_name
  storage_account_name = var.storage_account_name
  location = var.location
  image_name = var.image_name
  vm_size = var.vm_size
  os_disk_name = var.os_disk_name
  admin_username = var.admin_username
  admin_password = var.admin_password
  communicator = "none"
}

resource "ansible" "playbook" {
  playbook_file = "../playbook/site.yml"
}

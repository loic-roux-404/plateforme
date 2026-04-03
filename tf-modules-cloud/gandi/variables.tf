variable "gandi_token" {
  type = string
}

variable "domain" {
  type    = string
}

variable "target_ip" {
  type = string
    validation {
    condition = var.target_ip != ""
    error_message = "Empty Ip address"
  }
}

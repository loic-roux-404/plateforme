variable "gandi_token" {
  type = string
}

variable "paas_base_domain" {
  type    = string
  default = "k3s.test"
}

variable "target_ip" {
  type = string
}

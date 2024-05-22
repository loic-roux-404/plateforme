variable "ingress_hosts_internals" {
  description = "Ingress Hosts Internals"
  type        = list(string)
}

variable "internal_acme_network_ip" {
  description = "paas Internal ACME Network IP"
}

variable "internal_acme_hostname" {
  description = "paas Internal ACME Host"
}

variable "ingress_controller_ip" {
  type        = string
  description = "value of the ingress load balancer IP"
}


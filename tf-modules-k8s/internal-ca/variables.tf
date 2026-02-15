variable "ingress_hosts_internals" {
  description = "Ingress Hosts Internals"
  type        = list(string)
}

variable "ingress_controller_ip" {
  type        = string
  description = "value of the ingress load balancer IP"
}


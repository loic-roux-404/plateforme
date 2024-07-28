variable "cilium_version" {
  description = "The version of Cilium to deploy"
  type        = string
  default     = "1.16.0"
}

variable "k8s_endpoint" {
  default = "127.0.0.1"
}

variable "k8s_port" {
  default = "6443"
}

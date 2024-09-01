variable "cilium_namespace" {
  default = "kube-system"
}

variable "cilium_version" {
  description = "The version of Cilium to deploy"
  type        = string
  default     = "1.16.1"
}

variable "k3s_host" {
  type = string
}

variable "node_name" {
  type = string
}

variable "k3s_port" {
  default = "6443"
}

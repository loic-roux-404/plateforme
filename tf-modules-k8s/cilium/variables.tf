variable "cilium_namespace" {
  default = "kube-system"
}

variable "node_name" {
  type = string
}

variable "external_blocks" {
  description = "List of block ranges for external IP pool."
  type        = list(map(string))
  default = []
}

variable "internal_blocks" {
  description = "List of block ranges for internal IP pool."
  type        = list(map(string))
  default = []
}

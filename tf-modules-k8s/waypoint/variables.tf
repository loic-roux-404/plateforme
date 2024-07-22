variable "paas_hostname" {
  description = "value of the waypoint hostname"
}

variable "k8s_ingress_class" {
  description = "value of the k8s ingress class"
  default     = "nginx-ingress-controller"
}

variable "waypoint_extra_volume_mounts" {
  type = list(object({
    name      = string
    mountPath = string
    readOnly  = bool
  }))
}

variable "waypoint_extra_volumes" {
  type = list(object({
    name = string
    configMap = object({
      name = string
    })
  }))
}

variable "cert_manager_cluster_issuer" {
  description = "value of the cert-manager cluster issuer"
}

variable "dependency_update" {
  default = true
}

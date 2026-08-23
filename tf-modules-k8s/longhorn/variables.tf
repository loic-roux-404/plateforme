variable "paas_base_domain" {
  type = string
}

variable "k8s_ingress_class" {
  type = string
}

variable "cert_manager_cluster_issuer" {
  type = string
}

variable "object_storage" {
  type = object({
    access_key = string
    secret_key = string
    s3_url     = string
    region     = optional(string, "eu2")
  })
  description = "S3 object storage configuration for Longhorn backups"
}

variable "backup_bucket" {
  type        = string
  description = "S3 bucket name used as the Longhorn backup target"
}

variable "longhorn_ui_replicas" {
  description = "Replica count for the Longhorn UI"
  type        = number
  default     = 1
}

variable "longhorn_csi_replicas" {
  description = "Replica counts for Longhorn CSI components"
  type = object({
    attacher    = optional(number, 1)
    provisioner = optional(number, 1)
    resizer     = optional(number, 1)
    snapshotter = optional(number, 1)
  })
  default = {}
}

variable "longhorn_default_replica_count" {
  description = "Default replica count for Longhorn volumes and storage class"
  type        = number
  default     = 1
}

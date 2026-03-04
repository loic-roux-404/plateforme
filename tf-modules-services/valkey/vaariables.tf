
variable "valkey_service_name" {
  type        = string
  description = "Kubernetes Service name for Valkey"
  default     = "valkey"
}

variable "valkey_namespace" {
  type        = string
  description = "Kubernetes namespace where Valkey will be installed"
}

variable "valkey_chart_version" {
  type        = string
  description = "Version of the Valkey Helm chart"
  default     = "0.9.3"
}

variable "valkey_helm_repo" {
  type        = string
  description = "OCI or HTTP Helm repository URL for the Valkey chart"
  default     = "oci://ghcr.io/valkey-io/valkey-helm" # example, adjust to actual repo [web:19][web:22]
}

variable "replica_count" {
  type        = number
  description = "Number of Valkey replicas"
  default     = 1
}

variable "data_storage_enabled" {
  type        = bool
  description = "Enable persistent data storage for Valkey"
  default     = true
}

variable "data_storage_requestedSize" {
  type        = string
  description = "Requested size for Valkey data PVC"
  default     = "256Mi"
}

variable "data_storage_className" {
  type        = string
  description = "StorageClass name for Valkey data PVC"
  default     = "local-path"
}

variable "data_storage_keepPvc" {
  type        = bool
  description = "Keep the PVC when uninstalling the Valkey release"
  default     = false
}

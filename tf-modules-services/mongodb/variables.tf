variable "namespace" {
  type        = string
  description = "Namespace where MongoDB will be deployed"
}

variable "name" {
  type        = string
  default     = "appsmith-mongodb"
}

variable "chart_version" {
  type        = string
  default     = "18.6.20"
}

variable "replica_count" {
  type        = number
  default     = 1
}

variable "mongodb_storage_class" {
  type        = string
  default     = "local-path"
}

variable "mongodb_persistence_size" {
  type        = string
  default     = "512Mi"
}

variable "mongodb_resource_preset" {
  type    = string
  default = "small"

  validation {
    condition     = contains(["none", "nano", "micro", "small", "medium", "large", "xlarge", "2xlarge"], var.mongodb_resource_preset)
    error_message = "mongodb_resource_preset must be one of: none, nano, micro, small, medium, large, xlarge, 2xlarge"
  }
}

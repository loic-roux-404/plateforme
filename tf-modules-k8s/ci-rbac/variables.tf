variable "role_name" {
  type        = string
  default     = "ci-edit"
  description = "Name of the aggregated (extended edit) ClusterRole created by this module."
}

variable "namespaces" {
  type        = list(string)
  description = "Namespaces CI must be able to deploy into. Missing ones are created when create_namespaces is true."
}

variable "subjects" {
  type = list(object({
    kind      = string
    name      = string
    api_group = optional(string)
  }))
  description = "RBAC subjects (e.g. the Dex user for GitHub Actions) granted the CI roles."
}

variable "create_namespaces" {
  type        = bool
  default     = true
  description = "Create the namespaces that do not exist yet instead of failing."
}

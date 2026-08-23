variable "github_organization" {
  type    = string
  default = "org-404"
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "repo_secrets" {
  type        = map(string)
  default     = {}
  description = "Secrets to create on every repository returned by this module. Map keys are secret names and values are secret values."
}

variable "repo_variables" {
  type        = map(string)
  default     = {}
  description = "Variables to create on every repository returned by this module. Map keys are variable names and values are variable values."
}

variable "per_repo_variables" {
  type        = map(map(string))
  default     = {}
  description = "Variables to create on specific repositories only. Outer map key is the repository name, inner map keys are variable names."
}

variable "ignored_repos" {
  default = [".github", "plateforme"]
}

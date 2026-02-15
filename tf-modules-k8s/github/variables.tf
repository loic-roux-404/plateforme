variable "github_organization" {
  type    = string
  default = "org-404"
}

variable "github_team" {
  type    = string
  default = "ops-team-staging"
}

variable "github_token" {
  type      = string
  sensitive = true
}

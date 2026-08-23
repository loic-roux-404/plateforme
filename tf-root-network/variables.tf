variable "machine" {
  type = object({
    node_hostname = string
    node_id       = string
    node_ip       = string  })
}

variable "object_storage" {
  type = object({
    access_key = string
    secret_key = string
    s3_url     = string
    region     = optional(string, "eu2")
  })
  sensitive   = true
}

variable "github_team" {
  type = string
  default = "ops-team-staging"
}

variable "github_action_client_id" {
  default = "apps-github-actions-staging"
}

variable "gandi_token" {
  type     = string
  nullable = true
}

variable "paas_base_domain" {
  type    = string
  default = "kube.test"
}

variable "additional_domains" {
  type    = list(string)
  default = []
}

variable "ssh_connection" {
  type = object({
    user        = string
    public_key  = string
    private_key = string
  })
  default = {
    private_key = "~/.ssh/id_ed25519"
    public_key  = "~/.ssh/id_ed25519.pub"
    user        = "admin"
  }
  sensitive = true
}

variable "nix_flake" {
  type = string
}

variable "nix_flake_reset" {
  type = string
}

variable "remote_k3s_config_location" {
  default = "/etc/rancher/rke2/rke2.yaml"
}

variable "platform" {
  description = "The platform to deploy the infrastructure"
  default     = "libvirt"
}

variable "k3s_token" {
  default = "example-token"
}

variable "paas_base_domain" {
  default = "k3s.test"
}

variable "cert_manager_letsencrypt_env" {
  default = "local"
}

variable "cert_manager_namespace" {
  default = "cert-manager"
}

variable "cert_manager_email" {
  default = "toto@k3s.test"
}

variable "cert_manager_private_key_secret" {
  default = "test_secret"
}

variable "dex_namespace" {
  default = "dex"
}

variable "dex_client_id" {
  default = "paas"
}

variable "dex_client_secret" {
  default = "dex-client-secret"
}

variable "dex_github_client_id" {
  default = "client-id-example"
}

variable "dex_github_client_secret" {
  default = "secret-example"
}

variable "dex_github_client_org" {
  default = "esgi-immo-scanner"
}

variable "dex_github_client_team" {
  default = "ops-team"
}

variable "paas_namespace" {
  default = "default"
}

variable "paas_hostname" {
  default = "paas.k3s.test"
}

variable "k8s_ingress_class" {
  default     = "nginx"
  description = "ingress class"
}

variable "letsencrypt_envs" {
  description = "Letsencrypt Envs"
  type = object({
    local   = string
    staging = string
    prod    = string
  })
  default = {
    local   = "https://localhost:14000/dir"
    staging = "https://acme-v02.api.letsencrypt.org/directory"
    prod    = "https://acme-staging-v02.api.letsencrypt.org/directory"
  }
}

variable "letsencrypt_envs_ca_certs" {
  description = "Letsencrypt Envs CA Certs"
  type = object({
    local   = string
    staging = string
    prod    = string
  })
  default = {
    local   = "https://localhost:15000/roots/0"
    staging = "https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem"
    prod    = null
  }
}

variable "metallb_ip_range" {
  type        = string
  description = "value of the ip range"
  default     = null
}

variable "vm_ip" {
  default = "localhost"
}

variable "internal_network_ip" {
  default = "10.0.2.2"
}

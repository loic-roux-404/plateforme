variable "namespace" {
  description = "Namespace pour Smtp relay"
  type        = string
  default     = "smtp-relay"
}

variable "chart_version" {
  type        = string
  description = "Version of the bokysan/mail Helm chart to deploy"
  default = "5.1.0"
}

variable "allowed_sender_domains" {
  type        = list(string)
  default     = ["gmail.com"]
  description = "List of domains allowed to send via this relay (ALLOWED_SENDER_DOMAINS)"
}

variable "relay_host" {
  type        = string
  description = "Postfix RELAYHOST value, e.g. smtp.example.com:25"
  default     = "smtp.gmail.com"
}

variable "relay_username" {
  type        = string
  description = "Postfix RELAYHOST_USERNAME for authenticated relay"
}

variable "relay_tls_security_level" {
  type        = string
  default     = "may"
  description = "Postfix POSTFIX_smtp_tls_security_level value"
}

variable "config_postfix_overrides" {
  type        = map(string)
  default     = {}
  description = "Extra config.postfix key-values for the mail chart"
}

variable "relay_password" {
  type        = string
  sensitive   = true
  description = "Postfix RELAYHOST_PASSWORD for authenticated relay"
}

variable "extra_secret_env" {
  type        = map(string)
  default     = {}
  description = "Additional secret environment variables for the mail chart"
}

variable "persistence_size" {
  type        = string
  default     = "128Mi"
  description = "Persistent volume size for Postfix queue"
}

variable "persistence_storage_class" {
  type        = string
  default     = "local-path"
  description = "StorageClass for Postfix queue PVC"
}

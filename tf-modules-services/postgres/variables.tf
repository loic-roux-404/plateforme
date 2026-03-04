variable "postgresql_version" {
  default = "18.3.0"
}

variable "postgres_namespace" {
  default = "postgresql"
}

variable "postgres_db" {
  type = string
}

variable "postgres_user" {
  type = string
  default = "app"
}

variable "postgres_service_name" {
  default = "postgresql"
}

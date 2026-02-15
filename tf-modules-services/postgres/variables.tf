variable "postgresql_version" {
  default = "16.2.1"
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

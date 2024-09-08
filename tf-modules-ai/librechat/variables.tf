variable "mongo_database" {
  description = "The name of the MongoDB database to use."
  default = "librechat"
}

variable "mongo_host" {
  description = "The hostname of the MongoDB server."
}

variable "mongo_password" {
  description = "The password to use to connect to the MongoDB server."
}

variable "mongo_user" {
  description = "The username to use to connect to the MongoDB server."
}

variable "mongo_port" {
  default = 27017
}

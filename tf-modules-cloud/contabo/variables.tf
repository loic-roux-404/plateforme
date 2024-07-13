
variable "contabo_instance" {
  type = string
}

variable "image_version" {
  type = string
}

variable "image_url_format" {
  type = string
}

variable "ssh_connection" {
  type = object({
    user        = string
    public_key  = string
    private_key = string
  })
  sensitive = true
}

variable "node_hostname" {
  type = string
}

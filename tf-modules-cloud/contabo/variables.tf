
variable "contabo_instance" {
  type = string
}

variable "contabo_credentials" {
  type = object({
    oauth2_client_id     = string
    oauth2_client_secret = string
    oauth2_user          = string
    oauth2_pass          = string
  })
  sensitive = true
}

variable "image_version" {
  default = "1817d1d"
}

variable "image_url_format" {
  default = "https://github.com/loic-roux-404/k3s-paas/releases/download/nixos-%s/nixos.qcow2"
}

variable "ssh_connection" {
  type = object({
    user        = string
    public_key  = string
    private_key = string
  })
  sensitive = true
  default = {
    private_key = "~/.ssh/id_ed25519"
    public_key = "~/.ssh/id_ed25519.pub"
    user        = "admin"
  }
}

variable "node_hostname" {
  type = string
}

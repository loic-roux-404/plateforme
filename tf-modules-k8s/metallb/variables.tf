variable "metallb_ip_range" {
  type        = string
  description = "value of the ip range"
}

variable "metallb_manifests_metallb_native" {
  type    = string
  default = "https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml"
}

variable "metallb_manifests_metallb_frr" {
  type    = string
  default = "https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-frr.yaml"
}

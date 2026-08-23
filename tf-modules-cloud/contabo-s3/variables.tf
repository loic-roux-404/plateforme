variable "bucket_name" {
  type        = string
  description = "S3 bucket name (must be lowercase, 3-63 chars, DNS-compliant, globally unique on Contabo)"
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket deletion even when it contains objects"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the bucket"
  default     = {}
}

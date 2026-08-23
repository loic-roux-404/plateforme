resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = var.tags
}

# NOTE: No aws_s3_bucket_versioning and no aws_s3_bucket_public_access_block.
# Contabo S3 (Ceph RGW) rejects PutObject with AccessDenied on buckets that
# have versioning enabled OR a public access block configured, which breaks
# Longhorn backups and any object upload. Buckets are private by default.

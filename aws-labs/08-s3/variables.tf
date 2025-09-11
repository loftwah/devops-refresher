variable "bucket_name" {
  description = "S3 bucket name for app data (override). If null, a unique name is generated."
  type        = string
  default     = null
}

variable "bucket_prefix" {
  description = "Prefix used when auto-generating the S3 bucket name"
  type        = string
  default     = "devops-refresher-staging-app"
}

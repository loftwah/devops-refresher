variable "s3_bucket_name" {
  description = "S3 bucket name for app data (grants task role S3 access). Leave empty to skip."
  type        = string
  default     = ""
}

variable "grant_task_role_ssm_read" {
  description = "If true, grant task role SSM read on the provided ssm_path_prefix."
  type        = bool
  default     = false
}

variable "ssm_path_prefix" {
  description = "SSM path prefix for app config, e.g. /devops-refresher/staging/app"
  type        = string
  default     = ""
}

variable "grant_exec_role_ssm_read" {
  description = "If true, grant execution role SSM read on ssm_path_prefix (for SecureString usage)."
  type        = bool
  default     = true
}

variable "grant_exec_role_secrets_read" {
  description = "If true, grant execution role Secrets Manager read on path /devops-refresher/<env>/<service>/*"
  type        = bool
  default     = true
}

variable "secrets_path_prefix" {
  description = "Secrets Manager name prefix, e.g. /devops-refresher/staging/app"
  type        = string
  default     = "/devops-refresher/staging/app"
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN to allow Decrypt for SecureString/Secrets"
  type        = string
  default     = ""
}


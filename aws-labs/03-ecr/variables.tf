variable "region" {
  type        = string
  description = "AWS region for ECR"
  default     = "ap-southeast-2"
}

variable "repo_name" {
  type        = string
  description = "ECR repository name (supports namespace/repo)"
  default     = "demo-node-app"
}

variable "image_tag_mutability" {
  type        = string
  description = "ECR image tag mutability: MUTABLE or IMMUTABLE"
  default     = "IMMUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE"
  }
}

variable "force_delete" {
  type        = bool
  description = "Force delete repository even if images exist (lab convenience)"
  default     = true
}

variable "enable_kms_encryption" {
  type        = bool
  description = "Enable KMS CMK for ECR image encryption (default AES256 if false)"
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for ECR image encryption (required if enable_kms_encryption)"
  default     = ""
}

variable "lifecycle_keep_last" {
  type        = number
  description = "How many images to retain (older images expire)"
  default     = 10
}

variable "enable_pull_through_cache" {
  type        = bool
  description = "Create an ECR Pull Through Cache rule for upstream registry"
  default     = false
}

variable "upstream_registry_url" {
  type        = string
  description = "Upstream registry for pull-through cache (e.g., registry-1.docker.io)"
  default     = "registry-1.docker.io"
}

variable "ecr_cache_prefix" {
  type        = string
  description = "Repository prefix for pull-through cache (becomes part of image path)"
  default     = "dockerhub"
}

variable "tags" {
  description = "Base tags applied to all resources"
  type        = map(string)
  default = {
    Owner       = "Dean Lofts"
    Project     = "devops-refresher"
    App         = "devops-refresher"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

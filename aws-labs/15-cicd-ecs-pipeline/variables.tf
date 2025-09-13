variable "connection_arn" {
  description = "AWS CodeConnections (CodeStar Connections) ARN for GitHub"
  type        = string
  default     = "arn:aws:codeconnections:ap-southeast-2:139294524816:connection/9cb5e242-3d9c-4b3c-8fec-fd3fdea9e37e"
}

variable "repo_full_name" {
  description = "GitHub owner/repo for source"
  type        = string
  default     = "loftwah/demo-node-app"
}

variable "branch" {
  description = "Git branch to build from"
  type        = string
  default     = "main"
}

variable "cluster_name" {
  description = "ECS cluster name to deploy to"
  type        = string
  default     = "devops-refresher-staging"
}

variable "service_name" {
  description = "ECS service name to deploy"
  type        = string
  default     = "app"
}

variable "ecr_repo_name" {
  description = "ECR repository name for the app image"
  type        = string
  default     = "demo-node-app"
}

variable "artifacts_bucket_name" {
  description = "S3 bucket name for CodePipeline artifacts (must be globally unique)"
  type        = string
  default     = "devops-refresher-pipeline-artifacts-139294524816-apse2"
}

variable "create_artifacts_bucket" {
  description = "If true, create the artifacts bucket. If false, reuse an existing bucket named artifacts_bucket_name"
  type        = bool
  default     = true
}

variable "artifacts_bucket_randomize" {
  description = "If true and creating the bucket, append a random hex suffix to ensure uniqueness and avoid slow re-creates"
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region for pipeline resources (must match CodeConnections region)"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI/SDK profile to use for this lab"
  type        = string
  default     = "devops-sandbox"
}

variable "expected_account_id" {
  description = "Guardrail: expected AWS account ID. Plan/apply fails if not matched"
  type        = string
  default     = "139294524816"
}

variable "use_inline_buildspec" {
  description = "If true, inject inline buildspec into CodeBuild project; otherwise, expect buildspec in app repo"
  type        = bool
  default     = true
}

variable "inline_buildspec_override" {
  description = "Optional override for inline buildspec content (YAML). If empty, use the lab default."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    Owner       = "Dean Lofts"
    Project     = "devops-refresher"
    App         = "devops-refresher"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

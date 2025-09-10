variable "region" { type = string, default = "ap-southeast-2" }
variable "tags" {
  type = map(string)
  default = {
    Owner       = "Dean Lofts"
    Project     = "devops-refresher"
    App         = "devops-refresher"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

variable "codestar_connection_arn" { type = string, description = "Existing CodeStar Connections ARN" }
variable "github_full_repo_id" { type = string, description = "owner/repo for app source" }
variable "github_branch" { type = string, default = "main" }

variable "ecr_repository_url" { type = string, description = "ECR repository URL (from ECS outputs)" }

variable "ecs_cluster_name" { type = string }
variable "ecs_service_name" { type = string }
variable "container_name" { type = string, default = "app" }

variable "slack_notifier_arn" { type = string, default = "" }


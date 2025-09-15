variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS profile"
  type        = string
  default     = "devops-sandbox"
}

variable "connection_arn" {
  description = "CodeConnections ARN for GitHub"
  type        = string
  default     = "arn:aws:codeconnections:ap-southeast-2:139294524816:connection/9cb5e242-3d9c-4b3c-8fec-fd3fdea9e37e"
}

variable "repo_full_name" {
  description = "GitHub org/repo"
  type        = string
  default     = "loftwah/demo-node-app"
}

variable "branch" {
  description = "Git branch"
  type        = string
  default     = "main"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "devops-refresher-staging"
}

variable "namespace" {
  description = "K8s namespace"
  type        = string
  default     = "demo"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "demo-eks"
}

variable "chart_path" {
  description = "Chart path in this repo"
  type        = string
  default     = "aws-labs/kubernetes/helm/demo-app"
}

variable "values_file" {
  description = "Values file path"
  type        = string
  default     = "aws-labs/kubernetes/helm/demo-app/values.yml"
}

variable "ecr_repo_name" {
  description = "ECR repo name for the app"
  type        = string
  default     = "demo-node-app"
}

variable "chart_repo_url" {
  description = "Git URL of repo containing the Helm chart"
  type        = string
  default     = "https://github.com/loftwah/devops-refresher.git"
}

variable "chart_repo_ref" {
  description = "Git branch or tag to checkout for the charts repo"
  type        = string
  default     = "dl/aws-labs-eks"
}

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

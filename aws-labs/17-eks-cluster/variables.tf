variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS CLI/SDK profile"
  type        = string
  default     = "devops-sandbox"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "devops-refresher-staging"
}

variable "kubernetes_version" {
  description = "EKS version"
  type        = string
  default     = "1.31"
}

variable "desired_size" {
  description = "Node group desired size"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Node group min size"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Node group max size"
  type        = number
  default     = 3
}

variable "instance_types" {
  description = "EC2 instance types for managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "tags" {
  description = "Baseline tags"
  type        = map(string)
  default = {
    Owner       = "Dean Lofts"
    Project     = "devops-refresher"
    App         = "devops-refresher"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

variable "oidc_thumbprint" {
  description = "Thumbprint for the EKS OIDC provider root CA"
  type        = string
  # Default commonly used for oidc.eks.<region>.amazonaws.com as of 2024
  default = "9e99a48a9960b14926bb7f3b02e22da0ecd4e4b5"
}

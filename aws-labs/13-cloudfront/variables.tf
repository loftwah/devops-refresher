variable "region" {
  type        = string
  description = "Primary AWS region for resources (ALB, Route53 lookups)"
  default     = "ap-southeast-2"
}

variable "tags" {
  type        = map(string)
  description = "Base tags"
  default     = {
    Owner       = "Dean Lofts"
    Project     = "devops-refresher"
    App         = "devops-refresher"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

variable "hosted_zone_name" {
  type        = string
  description = "Public hosted zone name (e.g., aws.deanlofts.xyz)"
  default     = "aws.deanlofts.xyz"
}

variable "hosted_zone_id" {
  type        = string
  description = "Optional hosted zone ID (if known)"
  default     = ""
}

variable "ecs_domain" {
  type        = string
  description = "FQDN for ECS app"
  default     = "demo-node-app-ecs.aws.deanlofts.xyz"
}

variable "eks_domain" {
  type        = string
  description = "FQDN for EKS app"
  default     = "demo-node-app-eks.aws.deanlofts.xyz"
}

variable "ecs_alb_dns_name" {
  type        = string
  description = "ALB DNS name for the ECS service (origin)"
}

variable "eks_alb_dns_name" {
  type        = string
  description = "ALB DNS name for the EKS ingress (origin)"
}

variable "region" {
  type        = string
  description = "AWS region for the VPC"
  default     = "ap-southeast-2"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.64.0.0/16"
}

variable "azs" {
  type        = map(string)
  description = "AZ map for spreading subnets"
  default = {
    a = "ap-southeast-2a"
    b = "ap-southeast-2b"
  }
}

variable "enable_flow_logs" {
  type        = bool
  description = "Enable VPC Flow Logs to CloudWatch Logs"
  default     = false
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

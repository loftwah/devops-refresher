variable "aws_profile" {
  description = "AWS profile"
  type        = string
  default     = "devops-sandbox"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}
variable "tags" {
  description = "Base tags"
  type        = map(string)
  default = {
    Owner       = "Dean Lofts"
    Project     = "devops-refresher"
    App         = "devops-refresher"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
  default_tags {
    tags = var.tags
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

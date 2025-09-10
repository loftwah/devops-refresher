variable "aws_profile" {
  description = "AWS CLI/SDK profile to use"
  type        = string
  default     = "devops-sandbox"
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = var.tags
  }
}


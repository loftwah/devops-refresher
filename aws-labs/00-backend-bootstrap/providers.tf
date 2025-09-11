variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "devops-sandbox"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Owner       = "Dean Lofts"
      Environment = "staging"
      Project     = "devops-refresher"
      App         = "devops-refresher"
      ManagedBy   = "Terraform"
    }
  }
}


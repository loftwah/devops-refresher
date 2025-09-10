variable "aws_profile" {
  type        = string
  description = "AWS profile for auth"
  default     = "devops-sandbox"
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = var.tags
  }
}

# CloudFront ACM certs must be in us-east-1
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = var.tags
  }
}


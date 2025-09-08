provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Owner       = "Dean Lofts"
      Environment = "Development"
      Project     = "devops-refresher"
      App         = "devops-refresher"
      ManagedBy   = "Terraform"
    }
  }
}

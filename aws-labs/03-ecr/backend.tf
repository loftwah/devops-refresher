terraform {
  required_version = ">= 1.13.0"

  # Separate state for ECR; reuse the same bucket as prior labs
  backend "s3" {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/ecr/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
    profile      = "devops-sandbox"
  }
}


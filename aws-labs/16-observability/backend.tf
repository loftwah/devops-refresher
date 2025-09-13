terraform {
  required_version = ">= 1.13.0"
  backend "s3" {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/observability/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
    profile      = "devops-sandbox"
  }
}


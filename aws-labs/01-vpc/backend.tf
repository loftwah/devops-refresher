terraform {
  required_version = ">= 1.13.0"

  # Reuse the existing backend bucket from Lab 00
  backend "s3" {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/network/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
    profile      = "devops-sandbox"
  }
}


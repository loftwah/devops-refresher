terraform {
  required_version = ">= 1.13.0"

  # Separate state for endpoints; reuse the same bucket as Lab 01
  backend "s3" {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/network-endpoints/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
    profile      = "devops-sandbox"
  }
}


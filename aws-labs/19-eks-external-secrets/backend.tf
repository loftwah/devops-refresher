terraform {
  backend "s3" {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/eks-external-secrets/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}


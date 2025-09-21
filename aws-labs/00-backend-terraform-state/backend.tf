terraform {
  # Backend fully configured inline for this example repo
  backend "s3" {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "global/s3/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
    profile      = "devops-sandbox"
  }
}

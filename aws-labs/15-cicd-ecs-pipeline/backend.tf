terraform {
  required_version = ">= 1.13.0"

  # Uses the same remote state bucket pattern as other labs
  # Note: State bucket region can differ from resource region; set AWS_REGION env for resources.
  backend "s3" {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/cicd-ecs-pipeline/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
    profile      = "devops-sandbox"
  }
}


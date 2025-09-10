variable "region" { type = string, default = "ap-southeast-2" }

variable "tags" {
  type = map(string)
  default = {
    Owner       = "Dean Lofts"
    Project     = "devops-refresher"
    App         = "devops-refresher"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

variable "app_name" { type = string, default = "demo-node-app" }
variable "app_port" { type = number, default = 3000 }
variable "desired_count" { type = number, default = 2 }
variable "healthcheck_path" { type = string, default = "/healthz" }

variable "s3_bucket_name" { type = string, default = "devops-refresher-staging-app" }

variable "image_tag" { type = string, default = "staging" }


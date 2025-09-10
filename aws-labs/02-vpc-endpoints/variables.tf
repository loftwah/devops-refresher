variable "vpc_state_bucket" {
  description = "S3 bucket name for the VPC stack state (Lab 01)"
  type        = string
  default     = "tf-state-139294524816-us-east-1"
}

variable "vpc_state_key" {
  description = "S3 key for the VPC stack state (Lab 01)"
  type        = string
  default     = "staging/network/terraform.tfstate"
}

variable "vpc_state_region" {
  description = "Region of the S3 backend bucket"
  type        = string
  default     = "us-east-1"
}

variable "private_route_table_name" {
  description = "Tag Name for the private route table in the VPC (from Lab 01)"
  type        = string
  default     = "staging-private-rt"
}

variable "enable_s3_gateway" {
  description = "Create S3 Gateway VPC Endpoint"
  type        = bool
  default     = true
}

variable "enable_dynamodb_gateway" {
  description = "Create DynamoDB Gateway VPC Endpoint"
  type        = bool
  default     = false
}

variable "interface_endpoints" {
  description = "List of interface endpoint service suffixes to create"
  type        = list(string)
  default = [
    "ssm",
    "ec2messages",
    "ssmmessages",
    "ecr.api",
    "ecr.dkr",
    "logs"
  ]
}

# Convenience toggles for common interface endpoints
variable "enable_secretsmanager" {
  description = "Enable Secrets Manager interface endpoint"
  type        = bool
  default     = false
}

variable "enable_kms" {
  description = "Enable KMS interface endpoint"
  type        = bool
  default     = false
}

variable "enable_sts" {
  description = "Enable STS interface endpoint"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable CloudWatch Monitoring interface endpoint"
  type        = bool
  default     = false
}

variable "enable_efs" {
  description = "Enable EFS interface endpoint"
  type        = bool
  default     = false
}

variable "enable_events" {
  description = "Enable EventBridge (events) interface endpoint"
  type        = bool
  default     = false
}

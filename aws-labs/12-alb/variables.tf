variable "vpc_id" {
  description = "VPC ID (optional; read from Lab 01 if empty)"
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (optional; read from Lab 01 if empty)"
  type        = list(string)
  default     = []
}

variable "alb_sg_id" {
  description = "ALB security group ID"
  type        = string
  default     = ""
}

variable "target_port" {
  description = "Target port"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/healthz"
}

# HTTPS and DNS
variable "certificate_domain_name" {
  description = "Primary domain name for the ACM certificate (e.g., app.aws.deanlofts.xyz)"
  type        = string
  default     = ""
}

variable "hosted_zone_name" {
  description = "Route 53 hosted zone name (e.g., aws.deanlofts.xyz)"
  type        = string
  default     = "aws.deanlofts.xyz"
}

variable "record_name" {
  description = "DNS record name to point at the ALB (FQDN)"
  type        = string
  default     = "demo-node-app-ecs.aws.deanlofts.xyz"
}

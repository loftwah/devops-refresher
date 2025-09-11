variable "vpc_id" {
  description = "VPC ID (optional; read from Lab 01 if empty)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (optional; read from Lab 01 if empty)"
  type        = list(string)
  default     = []
}

variable "app_sg_id" {
  description = "App SG ID (source) (optional; read from Lab 07 if empty)"
  type        = string
  default     = ""
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "DB name"
  type        = string
}

variable "db_user" {
  description = "DB username"
  type        = string
}

variable "db_password" {
  description = "DB password"
  type        = string
  sensitive   = true
  # Empty default prevents interactive prompt; actual value is generated
  # unless explicitly provided via tfvars or -var.
  default = ""
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "service" {
  description = "Service name"
  type        = string
  default     = "app"
}

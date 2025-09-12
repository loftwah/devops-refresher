variable "cluster_arn" {
  description = "ECS cluster ARN (optional; read from Lab 13 if empty)"
  type        = string
  default     = ""
}

variable "service_name" {
  description = "ECS service name"
  type        = string
  default     = "app"
}

variable "image" {
  description = "Container image"
  type        = string
  default     = ""
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "Task CPU"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory (MiB)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Service desired count"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "Private subnet IDs (optional; read from Lab 01 if empty)"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "App security group IDs (optional; read from Lab 07 if empty)"
  type        = list(string)
  default     = []
}

variable "target_group_arn" {
  description = "ALB target group ARN (optional; read from Lab 12 if empty)"
  type        = string
  default     = ""
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN (optional; read from Lab 06 if empty)"
  type        = string
  default     = ""
}

variable "task_role_arn" {
  description = "ECS task role ARN (optional; read from Lab 06 if empty)"
  type        = string
  default     = ""
}

variable "log_group_name" {
  description = "CloudWatch Logs group name"
  type        = string
  default     = "/aws/ecs/devops-refresher-staging"
}

variable "secrets" {
  description = "Container secrets"
  type        = list(object({ name = string, valueFrom = string }))
  default     = []
}

variable "environment" {
  description = "Container environment variables (non-sensitive)"
  type        = list(object({ name = string, value = string }))
  default     = []
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for the service"
  type        = bool
  default     = true
}

variable "ssm_path_prefix" {
  description = "SSM/Secrets path prefix, e.g. /devops-refresher/staging/app"
  type        = string
  default     = "/devops-refresher/staging/app"
}

variable "auto_load_env_from_ssm" {
  description = "If true, auto-populate container environment from SSM parameters under ssm_path_prefix"
  type        = bool
  default     = true
}

variable "auto_load_secrets_from_sm" {
  description = "If true, auto-populate container secrets from Secrets Manager under ssm_path_prefix"
  type        = bool
  default     = true
}

variable "secret_keys" {
  description = "Secret keys (names) to load from Secrets Manager when auto_load_secrets_from_sm is true"
  type        = list(string)
  default     = ["DB_PASS", "APP_AUTH_SECRET"]
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "service_name" {
  description = "Primary service name for ECS/RDS/Redis naming"
  type        = string
  default     = "app"
}

variable "alert_email" {
  description = "Email address to subscribe for alerts"
  type        = string
  default     = "dean+aws@deanlofts.xyz"
}

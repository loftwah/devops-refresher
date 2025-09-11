variable "env" {
  description = "Environment"
  type        = string
  default     = "staging"
}

variable "service" {
  description = "Service name"
  type        = string
  default     = "app"
}

# Dynamic inputs from other labs
variable "s3_bucket" {
  description = "S3 bucket name (optional; read from Lab 08 if empty)"
  type        = string
  default     = ""
}

variable "db_host" {
  description = "DB host (optional; read from Lab 09 if empty)"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "DB port (optional; read from Lab 09 if empty)"
  type        = number
  default     = 0
}

variable "db_user" {
  description = "DB user (optional; read from Lab 09 if empty)"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "DB name (optional; read from Lab 09 if empty)"
  type        = string
  default     = ""
}

variable "redis_host" {
  description = "Redis host (optional; read from Lab 10 if empty)"
  type        = string
  default     = ""
}

variable "redis_port" {
  description = "Redis port (optional; read from Lab 10 if empty)"
  type        = number
  default     = 0
}

# Secrets (optional). Provide non-null values to create versions.
variable "secret_values" {
  description = "Secret key/values for Secrets Manager"
  type        = map(string)
  default     = {
    DB_PASS    = null
    REDIS_PASS = null
  }
}

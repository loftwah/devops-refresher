variable "vpc_id" {
  description = "VPC ID where SGs are created (optional; auto-detected from Lab 01 state if empty)"
  type        = string
  default     = ""
}

variable "container_port" {
  description = "App container port exposed to ALB"
  type        = number
  default     = 3000
}

variable "alb_http_ingress_cidrs" {
  description = "Allowed CIDRs for ALB HTTP (80)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_https_ingress_cidrs" {
  description = "Allowed CIDRs for ALB HTTPS (443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

output "alb_sg_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "Security group ID for app tasks/pods"
  value       = aws_security_group.app.id
}


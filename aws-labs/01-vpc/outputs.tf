output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = [for k, s in aws_subnet.public : s.id]
  description = "List of public subnet IDs (2)"
}

output "private_subnet_ids" {
  value       = [for k, s in aws_subnet.private : s.id]
  description = "List of private subnet IDs (2)"
}


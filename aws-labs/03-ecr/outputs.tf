output "repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.this.name
}

output "repository_url" {
  description = "ECR repository URL (for docker push)"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.this.arn
}

output "pull_through_cache_uri_hint" {
  description = "If enabled, images pull via: <account>.dkr.ecr.<region>.amazonaws.com/<prefix>/..."
  value       = var.enable_pull_through_cache ? aws_ecr_pull_through_cache_rule.upstream[0].ecr_repository_prefix : ""
}


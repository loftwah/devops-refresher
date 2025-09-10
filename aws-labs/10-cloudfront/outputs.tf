output "ecs_distribution_domain" { value = aws_cloudfront_distribution.ecs.domain_name }
output "eks_distribution_domain" { value = aws_cloudfront_distribution.eks.domain_name }
output "ecs_distribution_id"     { value = aws_cloudfront_distribution.ecs.id }
output "eks_distribution_id"     { value = aws_cloudfront_distribution.eks.id }


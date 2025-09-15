output "app_irsa_role_arn" { value = aws_iam_role.app_irsa.arn }
output "release_name" { value = var.release_name }


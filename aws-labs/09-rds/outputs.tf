output "db_host" { value = aws_db_instance.postgres.address }
output "db_port" { value = aws_db_instance.postgres.port }
output "db_name" { value = aws_db_instance.postgres.db_name }
output "db_user" { value = aws_db_instance.postgres.username }
output "rds_sg_id" { value = aws_security_group.rds.id }

output "db_password_secret_arn" {
  description = "Secrets Manager ARN for the DB password"
  value       = aws_secretsmanager_secret.db_password.arn
}

# RDS (PostgreSQL)

## Objectives

- Provision a PostgreSQL instance in private subnets with least-privilege access.
- Expose outputs consumed by Parameter Store and app deployment.

## Prerequisites

- VPC with private subnets and NAT.
- Security group for app tasks/pods to allow outbound to DB port (5432).

## Tasks

1. Subnet group and security groups

```hcl
resource "aws_db_subnet_group" "this" {
  name       = "rds-app"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "rds" {
  name        = "rds-app"
  description = "RDS access for app"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "from_app_sg" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.app_sg_id # ALB->ECS/EKS workload SG
}
```

2. RDS instance

```hcl
resource "aws_db_instance" "postgres" {
  identifier              = "app-postgres"
  engine                  = "postgres"
  engine_version          = "14"
  instance_class          = var.instance_class
  allocated_storage       = 20
  db_name                 = var.db_name
  username                = var.db_user
  password                = local.db_password_effective
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
}
```

3. Outputs

```hcl
output "db_host" { value = aws_db_instance.postgres.address }
output "db_port" { value = aws_db_instance.postgres.port }
output "db_name" { value = aws_db_instance.postgres.db_name }
output "db_user" { value = aws_db_instance.postgres.username }
output "db_password_secret_arn" { value = aws_secretsmanager_secret.db_password.arn }
```

## Acceptance Criteria

- RDS instance available in private subnets.
- Only app SG allowed inbound on 5432.
- Outputs present for host, port, db name, user, and password secret ARN.

## Variables, Defaults, and Non-Interactive Applies

- This lab is non-interactive. Provide values via `*.auto.tfvars` files or explicit `-var` flags.
- Terraform automatically loads:
  - `terraform.tfvars` and `terraform.tfvars.json`
  - Any `*.auto.tfvars` and `*.auto.tfvars.json` files (lexicographic order)
- We include `staging.auto.tfvars` as an example. You can add `development.auto.tfvars` and `production.auto.tfvars` for other environments. Use full names like `development`, `staging`, and `production`.
- Recommended naming for DB values:
  - `db_name`: include service and environment, e.g., `app_staging` or `devops_refresher_app_staging`
  - `db_user`: app-scoped user per env, e.g., `app_user_staging`

## Secrets Handling

- If `var.db_password` is not set, a strong password is generated and stored in Secrets Manager at `/devops-refresher/${var.env}/${var.service}/DB_PASS`.
- The secret ARN is output as `db_password_secret_arn` for consumers like ECS to reference directly.

## Parameter Store (Next Lab)

- Lab 11 reads RDS outputs via `terraform_remote_state` and writes non-secrets (DB host/port/user/name) to SSM Parameter Store.
- It does not overwrite the DB password secret created here; it can create other secrets if provided.

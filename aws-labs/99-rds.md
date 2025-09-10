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
  password                = var.db_password # or use Secrets Manager + rotation
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
```

## Acceptance Criteria

- RDS instance available in private subnets.
- Only app SG allowed inbound on 5432.
- Outputs present for host, port, db name, and user.

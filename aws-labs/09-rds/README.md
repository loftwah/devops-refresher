# Lab 09 – RDS (PostgreSQL)

## What Terraform Actually Creates (main.tf)

- Reads VPC, private subnets, and `app_sg_id` from remote state when not provided via variables.
- `aws_db_subnet_group.this` for private subnet placement.
- `aws_security_group.rds` and an ingress rule allowing 5432 ONLY from `app_sg_id`.
- `aws_db_instance.postgres`:
  - Engine `postgres`, version `14`, `db.t4g.micro` by default.
  - `publicly_accessible = false`, `skip_final_snapshot = true`, `deletion_protection = false` for lab convenience.
  - Credentials: `var.db_user` and `var.db_password` or a generated strong password when unset.
- Database password is stored in Secrets Manager as `/devops-refresher/${var.env}/${var.service}/DB_PASS` with a created secret version.
- Outputs: `db_host`, `db_port`, `db_name`, `db_user`, `db_password_secret_arn`, `rds_sg_id`.

## Variables (variables.tf)

- `vpc_id`, `private_subnet_ids`, `app_sg_id`: optional; auto‑discovered from prior labs if empty.
- `instance_class` (default `db.t4g.micro`).
- `db_name` (required), `db_user` (required), `db_password` (optional; empty default triggers generation).
- `env` (default `staging`), `service` (default `app`).

## Apply

```bash
cd aws-labs/09-rds
terraform init
terraform apply -auto-approve \
  -var db_name=app \
  -var db_user=appuser

# Optional: provide your own password instead of auto-generation
# -var db_password='StrongPass...'
```

## Security Model

- DB is in private subnets; no public access.
- Only the app’s SG (`app_sg_id`) can connect on 5432.
- Password is never written to SSM; it lives in Secrets Manager and is referenced via `db_password_secret_arn` by workloads.

## How Other Labs Use This

- Parameter Store (Lab 11) pulls `db_host`, `db_port`, `db_user`, `db_name` from this stack and writes SSM parameters.
- Workloads (ECS/EKS) consume non‑secrets from SSM and the password from Secrets Manager using the output ARN.

## Outputs

- `db_host`, `db_port`, `db_name`, `db_user`, `db_password_secret_arn`, `rds_sg_id`.

## Cleanup

```bash
terraform destroy -auto-approve
```

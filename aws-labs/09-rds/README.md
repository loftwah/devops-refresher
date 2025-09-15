# Lab 09 – RDS (PostgreSQL)

## What Terraform Actually Creates (main.tf)

Related docs: `docs/runbooks/rotate-db-password.md`

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

## Why It Matters

- Parameter groups control engine settings and often require a reboot to apply — easy to miss. Multi‑AZ is HA for a single database, not read scaling. IAM Database Authentication avoids static passwords but changes connection flows. Teardown order matters when replicas or snapshots exist.

## Mental Model

- Security first: private subnets, SG‑based ingress from app only, and secrets in Secrets Manager.
- Parameter groups: attach a custom parameter group to change defaults; static parameters apply on reboot.
- High availability vs read scaling:
  - Multi‑AZ: synchronous standby in another AZ; automatic failover; no read offload.
  - Read replicas: asynchronous; for read scaling; promote for DR.
- IAM DB Auth: short‑lived auth tokens via IAM; requires SSL/TLS and `rds_iam` flag on the instance and user mapping in the DB.

## Verification

```bash
# Confirm SG ingress (5432) is only from app SG
aws ec2 describe-security-groups --group-ids <rds-sg-id> \
  --query 'SecurityGroups[0].IpPermissions'

# Confirm instance settings
aws rds describe-db-instances --db-instance-identifier <id> \
  --query 'DBInstances[0].{MultiAZ:MultiAZ,Public:PubliclyAccessible,Status:DBInstanceStatus,EngineVersion:EngineVersion}'
```

## Troubleshooting

- Cannot connect: ensure you are running from a host with the app SG, port 5432 open, and the endpoint resolves privately.
- Parameter change not applied: check whether it is a static parameter (requires reboot) and that the instance uses your custom parameter group.
- Password rotation: after updating the secret in Secrets Manager, restart tasks or rotate connections to pick up the new value.

## Teardown Checklist

1. Delete read replicas first (if any).
2. Optionally take a final snapshot of the primary.
3. Delete the primary instance.
4. Remove the subnet group and SG if no longer needed.

## Check Your Understanding

- What’s the difference between Multi‑AZ and read replicas?
- How do you enable IAM DB Auth and what changes for the client?
- Which parameter changes require a reboot and how do you apply them safely?

# Lab 11 – Parameter Store (SSM) + Secrets

## Objectives

- Store non-secrets as SSM parameters; keep secrets in Secrets Manager.
- Populate from outputs of the S3 (app bucket), RDS (PostgreSQL), and Redis (ElastiCache) stacks via remote state.

## Prerequisites

- S3 (app bucket): provides `bucket_name`.
- RDS (PostgreSQL): provides `db_host`, `db_port`, `db_name`, `db_user`.
  - Note: The RDS stack also creates the database password in Secrets Manager at `/devops-refresher/{env}/{service}/DB_PASS`. Do not pass `DB_PASS` here unless you intend to overwrite it.
- Redis (ElastiCache): provides `redis_host`, `redis_port`.

## Inputs Consumed and Sources

- `s3_bucket`: defaults from S3 remote state output `bucket_name`.
- `db_host`, `db_port`, `db_user`, `db_name`: default from RDS remote state outputs.
- `redis_host`, `redis_port`: default from Redis remote state outputs.
- You may override any of the above via tfvars or `-var` when needed.

## Apply

```bash
cd aws-labs/11-parameter-store
terraform init
terraform apply -auto-approve

# Optional overrides (when running in isolation or for custom values)
# -var env=staging -var service=app
# -var s3_bucket=... -var db_host=... -var db_port=... -var db_user=... -var db_name=...
# -var redis_host=... -var redis_port=...
```

Notes:

- Values default from remote state via `terraform_remote_state`; the long `-var` form is optional.
- In most cases you can simply run: `terraform apply -auto-approve`.
- Override any value by passing `-var` or by providing `*.auto.tfvars` files.

Redis TLS:

- ElastiCache Redis enables TLS (`transit_encryption_enabled = true`).
- This lab now publishes `REDIS_URL=rediss://<host>:<port>` alongside `REDIS_HOST` and `REDIS_PORT` to simplify client configuration.

To create additional secret versions, pass `-var secret_values` with non-null values (e.g., `REDIS_PASS`). `DB_PASS` is created in Lab 09 and should typically be omitted here.

## Outputs

- `ssm_path_prefix` → `/devops-refresher/{env}/{service}`.

## Secrets Manager (DB password and app auth secret)

- The database password is not stored in SSM. It is created by the RDS stack in Secrets Manager at `/devops-refresher/{env}/{service}/DB_PASS`.
- The application auth secret (`APP_AUTH_SECRET`) is automatically created by this stack if not provided via `secret_values` (length configurable via `app_auth_secret_length`).
- This stack does not overwrite existing secrets unless you provide non-null values in `var.secret_values`.

### Consuming in Workloads

- ECS Task Definition: reference the DB password secret ARN (output by RDS) under `secrets`, and map SSM params as environment variables.
- EKS: use the Secrets Store CSI Driver to mount Secrets Manager and SSM parameters into a Kubernetes Secret, then `envFrom` it in pods.

## Consumption

- ECS: map Secrets Manager ARNs via task definition `secrets`; fetch SSM String params at startup or template into env at deploy time.
- EKS: use Secrets Store CSI Driver to sync SSM + Secrets into a Kubernetes Secret and `envFrom` it.

## Cleanup

```bash
terraform destroy -auto-approve
```

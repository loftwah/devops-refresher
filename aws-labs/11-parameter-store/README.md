# Lab 11 – Parameter Store (SSM) + Secrets

## Objectives

- Store non-secrets as SSM parameters; store secrets in Secrets Manager.
- Populate from outputs of S3, RDS, and Redis labs.

## Prerequisites

- Lab 08 S3: `bucket_name`.
- Lab 09 RDS: `db_host`, `db_port`, `db_name`, `db_user`.
  - Note: The RDS lab also creates the `DB_PASS` secret in Secrets Manager. Do not pass `DB_PASS` here unless you intend to overwrite it.
- Lab 10 Redis: `redis_host`, `redis_port`.

## Apply

```bash
cd aws-labs/11-parameter-store
terraform init
terraform apply \
  -var env=staging -var service=app \
  -var s3_bucket=$(cd ../08-s3 && terraform output -raw bucket_name) \
  -var db_host=$(cd ../09-rds && terraform output -raw db_host) \
  -var db_port=$(cd ../09-rds && terraform output -raw db_port) \
  -var db_user=$(cd ../09-rds && terraform output -raw db_user) \
  -var db_name=$(cd ../09-rds && terraform output -raw db_name) \
  -var redis_host=$(cd ../10-elasticache-redis && terraform output -raw redis_host) \
  -var redis_port=$(cd ../10-elasticache-redis && terraform output -raw redis_port) \
  -auto-approve
```

Notes:
- Values default from remote state of Labs 08/09/10 via `terraform_remote_state`; the long `-var` form is optional.
- In most cases you can simply run: `terraform apply -auto-approve`.
- Override any value by passing `-var` or by providing `*.auto.tfvars` files.

To create additional secret versions, pass `-var secret_values` with non-null values (e.g., `REDIS_PASS`). `DB_PASS` is created in Lab 09 and should typically be omitted here.

## Outputs

- `ssm_path_prefix` → `/devops-refresher/staging/app`.

## Consumption

- ECS: map Secrets Manager ARNs via task definition `secrets`; fetch SSM String params at startup or template into env at deploy time.
- EKS: use Secrets Store CSI Driver to sync SSM + Secrets into a Kubernetes Secret and `envFrom` it.

## Cleanup

```bash
terraform destroy -auto-approve
```

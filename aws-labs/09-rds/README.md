# Lab 09 – RDS (PostgreSQL)

## Objectives

- Provision PostgreSQL in private subnets with least-privilege access.
- Export outputs for Parameter Store and app deployment.

## Prerequisites

- Lab 01 VPC applied: `vpc_id`, `private_subnet_ids`.
- Lab 07 Security Groups applied: `app_sg_id`.

## Apply

```bash
cd ../09-rds
terraform init
terraform apply \
  -var db_name=app \
  -var db_user=appuser \
  -var db_password=CHANGEME-strong-pass \
  -auto-approve
```

## Outputs

- `db_host`, `db_port`, `db_name`, `db_user` for Parameter Store.

## Security

- Only `app_sg_id` can connect on 5432. Instance is private.

Note: VPC ID, private subnets, and `app_sg_id` are auto-detected from Labs 01 and 07 via remote state.

## Cleanup

```bash
terraform destroy -auto-approve
```

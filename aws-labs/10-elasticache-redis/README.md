# Lab 10 – ElastiCache (Redis)

## Objectives

- Provision Redis in private subnets with least-privilege access.
- Export outputs for Parameter Store and app deployment.

## Prerequisites

- Lab 01 VPC applied: `vpc_id`, `private_subnet_ids`.
- Lab 07 Security Groups applied: `app_sg_id`.

## Apply

```bash
cd aws-labs/10-elasticache-redis
terraform init
terraform apply -auto-approve

# Optional overrides (when running in isolation)
# -var vpc_id=... \
# -var 'private_subnet_ids=["subnet-...","subnet-..."]' \
# -var app_sg_id=...
```

## Outputs

- `redis_host`, `redis_port` for Parameter Store.

## Security

- Only `app_sg_id` can connect on 6379. Cluster is private.

## Cleanup

```bash
terraform destroy -auto-approve
```

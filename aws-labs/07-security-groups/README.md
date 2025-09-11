# Lab 07 – Security Groups (ALB + App)

## Objectives

- Create shared security groups used by multiple labs:
  - `alb_sg`: Allows 80/443 from the internet to ALB; egress all.
  - `app_sg`: Allows app port only from `alb_sg`; egress all.

## Prerequisites

- Lab 01 VPC applied. You need: `vpc_id`.

## Apply

```bash
cd aws-labs/07-security-groups

terraform init
terraform apply -auto-approve
```

## Outputs

- `alb_sg_id`: Attach to the ALB in Lab 99-ALB.
- `app_sg_id`: Use for ECS service ENIs (or EKS workloads) and as source for RDS/Redis inbound.

Get values:

```bash
terraform output -raw alb_sg_id
terraform output -raw app_sg_id
```

## Downstream Usage

- Lab 99-RDS: allow 5432 from `app_sg_id`.
- Lab 99-Redis: allow 6379 from `app_sg_id`.
- Lab 99-ALB: assign `alb_sg_id` to the ALB.
- Lab 99-ECS: assign `app_sg_id` to the service/task networking.

## Cleanup

```bash
terraform destroy -auto-approve
```

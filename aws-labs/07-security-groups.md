# Security Groups (Shared: ALB + App)

## Objectives

- Create shared security groups used across labs:
  - `alb_sg`: Allow HTTP/HTTPS from the internet to the ALB.
  - `app_sg`: Allow app port only from `alb_sg`; used by ECS tasks/EKS pods.
- Export outputs for later labs (ALB, ECS, RDS, Redis).

## Why a dedicated lab?

- These SGs are “edge” and “workload” primitives reused by many resources. Keeping them in one small stack avoids circular dependencies and keeps per‑resource SGs close to those resources (RDS/Redis SGs live in their labs and reference `app_sg_id`).

## Prerequisites

- VPC from Lab 01 (`vpc_id`).

## Files

- `aws-labs/07-security-groups/` (Terraform): creates and outputs `alb_sg` and `app_sg`.

## Apply

```bash
cd aws-labs/07-security-groups
terraform init
terraform apply \
  -var vpc_id=$(cd ../01-vpc && terraform output -raw vpc_id) \
  -var region=ap-southeast-2 \
  -var aws_profile=devops-sandbox \
  -auto-approve
```

## Outputs

- `alb_sg_id`: Attach to ALB in the ALB lab.
- `app_sg_id`: Attach to ECS task ENIs or EKS worker pods/services.

## Downstream Usage

- RDS lab: create `rds_sg` that allows 5432 from `app_sg_id`.
- ElastiCache lab: create `redis_sg` that allows 6379 from `app_sg_id`.
- ECS lab: reference `app_sg_id` for the service/task networking.
- ALB lab: reference `alb_sg_id` for the load balancer.

## Acceptance Criteria

- ALB SG permits 80/443 from allowed CIDRs (default 0.0.0.0/0) and has egress 0.0.0.0/0.
- App SG permits only the app port from the ALB SG and has egress 0.0.0.0/0.
- Outputs emitted for both SG IDs.

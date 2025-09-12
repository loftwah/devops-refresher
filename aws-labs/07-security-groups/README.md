# Lab 07 – Security Groups (ALB + App)

## What Terraform Actually Creates (main.tf)

- Reads VPC ID from remote state when `var.vpc_id` is empty.
- `aws_security_group.alb` in that VPC.
  - Ingress rules:
    - 80 from `var.alb_http_ingress_cidrs` (default `0.0.0.0/0`).
    - 443 from `var.alb_https_ingress_cidrs` (default `0.0.0.0/0`).
  - Egress all (`0.0.0.0/0`).
- `aws_security_group.app` in the same VPC.
  - Ingress rule from the ALB SG only, to `var.container_port` (default `3000`).
  - Egress all.
- Outputs: `alb_sg_id`, `app_sg_id`.

## Variables (variables.tf)

- `vpc_id` (string, default ""): leave empty to auto‑discover from the VPC lab.
- `container_port` (number, default 3000): app/container port opened from ALB to app.
- `alb_http_ingress_cidrs` (list(string), default `["0.0.0.0/0"]`).
- `alb_https_ingress_cidrs` (list(string), default `["0.0.0.0/0"]`).

## Why It’s Structured This Way

- These two SGs are primitives reused by multiple labs. Keeping them in a small, independent stack avoids circular references and lets downstream labs (ALB, ECS, RDS, Redis) depend on stable outputs.

## Apply

```bash
cd aws-labs/07-security-groups
terraform init
terraform apply -auto-approve

# Optional: tighten CIDRs or change container port
# terraform apply -auto-approve \
#   -var 'alb_http_ingress_cidrs=["203.0.113.0/24"]' \
#   -var 'alb_https_ingress_cidrs=["203.0.113.0/24"]' \
#   -var container_port=3000
```

## Outputs

- `alb_sg_id`: attach to the ALB (Lab 12).
- `app_sg_id`: attach to ECS service ENIs and reference as source in RDS/Redis labs.

Get values quickly:

```bash
terraform output -raw alb_sg_id
terraform output -raw app_sg_id
```

## Downstream Usage

- RDS (Lab 09): allow 5432 from `app_sg_id`.
- Redis (Lab 10): allow 6379 from `app_sg_id`.
- ALB (Lab 12): assign `alb_sg_id` to the ALB.
- ECS (Lab 14): assign `app_sg_id` to the service/task networking.

## Cleanup

```bash
terraform destroy -auto-approve
```

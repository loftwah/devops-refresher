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

Related docs: `docs/security-groups.md`, `docs/resource-reference.md`

## Why It Matters

- SG vs NACL, ephemeral ports, and SG references are common interview and on‑call topics. Most connectivity issues are miswired SGs rather than routing.

## Mental Model

- Security Groups are stateful: return traffic is automatically allowed.
- Reference SGs instead of CIDRs whenever possible (e.g., allow ALB SG → app SG on app port). This survives IP changes and simplifies least‑priv.
- ALB health checks originate from the ALB SG; the app must allow that SG on the container port.

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

## Verification

```bash
# Confirm ALB SG allows 80/443, app SG allows from ALB SG to app port
aws ec2 describe-security-groups --group-ids <alb-sg> <app-sg> \
  --query 'SecurityGroups[].{Name:GroupName,Ingress:IpPermissions}'
```

Optional: use Reachability Analyzer (see `docs/resource-reference.md`) to validate end‑to‑end path from ALB ENI to app ENI.

## Troubleshooting

- Health checks failing: app SG is not allowing traffic from ALB SG on the correct port, or task is on a different port than target group.
- Can’t reach app from the Internet: ALB SG inbound missing 80/443 or NACL denies in public subnet; verify SGs first.
- Random failures: overlapping/conflicting SGs; consolidate and keep rules explicit.

## Teardown

- Destroy consumers first (ALB/ECS). If SG deletion is blocked, list attached ENIs and detach/destroy referencing resources.

## Check Your Understanding

- Why are SGs preferred over NACLs for service‑to‑service controls?
- How do SG references reduce operational toil compared to CIDR rules?
- Which SG sees the inbound health check traffic and on which port?

## Cleanup

```bash
terraform destroy -auto-approve
```

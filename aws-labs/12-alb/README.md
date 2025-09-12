# Lab 12 – Application Load Balancer

## Objectives

- Create an ALB in public subnets, fronting the app target group on port 3000.
- Add HTTPS via ACM (DNS validation) and Route 53 alias; redirect HTTP→HTTPS.

## Prerequisites

- Lab 01 VPC: `vpc_id`, `public_subnet_ids`.
- Lab 07 Security Groups: `alb_sg_id`.
- Route 53 hosted zone exists for `aws.deanlofts.xyz` (from Lab 05).

## Apply

```bash
cd aws-labs/12-alb
terraform init
terraform apply -auto-approve

# Optional overrides (if running in isolation or customizing)
# -var vpc_id=... \
# -var 'public_subnet_ids=["subnet-...","subnet-..."]' \
# -var alb_sg_id=... \
# -var hosted_zone_name=aws.deanlofts.xyz \
# -var record_name=demo-node-app-ecs.aws.deanlofts.xyz \
# -var certificate_domain_name=demo-node-app-ecs.aws.deanlofts.xyz \
# -var target_port=3000 \
# -var health_check_path=/healthz
```

## Outputs

- `alb_dns_name`, `tg_arn`, `certificate_arn`, `record_fqdn`.

## Notes

- Target type `ip` for Fargate. Health checks use `/healthz`.
- ACM uses DNS validation in Route 53. Ensure the hosted zone exists for `aws.deanlofts.xyz`.

### Inputs and Auto‑discovery

- Precedence for inputs: explicit variable values override auto‑discovered values.
- Auto‑discovery reads remote state from prior labs when variables are unset:
  - `vpc_id`, `public_subnet_ids` ← Lab 01 VPC state
  - `alb_sg_id` ← Lab 07 Security Groups state
  - `certificate_domain_name` defaults to `record_name` if unset
  - `record_name` defaults to `demo-node-app-ecs.aws.deanlofts.xyz`
- Result: fully non‑interactive applies once prior labs are applied, but you can still override any input.

See also: `docs/decisions/ADR-001-alb-tls-termination.md` for design rationale, tradeoffs (SANs, end‑to‑end TLS), and checklist.

## Cleanup

```bash
terraform destroy -auto-approve
```

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

### What Terraform Actually Creates (main.tf)

- Auto‑discovers VPC/public subnets and ALB SG from Labs 01 and 07 when variables are empty.
- `aws_lb.app` in public subnets with the provided ALB SG.
- `aws_lb_target_group.app` (HTTP, port `var.target_port`, target_type `ip`) with a `/healthz` health check by default.
- `aws_acm_certificate.this` for `var.certificate_domain_name` (defaults to `var.record_name`) with DNS validation records in Route 53.
- `aws_lb_listener.https` on 443 using the validated certificate and forwarding to the TG.
- `aws_lb_listener.http` on 80 redirecting to 443.
- `aws_route53_record.app_alias` A‑alias pointing the FQDN to the ALB.

### Variables (variables.tf)

- `vpc_id`, `public_subnet_ids`, `alb_sg_id` (optional; auto‑discovered if empty).
- `target_port` (default 3000), `health_check_path` (default `/healthz`).
- `certificate_domain_name` (defaults to `record_name` if empty).
- `hosted_zone_name` (default `aws.deanlofts.xyz`), `record_name` (default `demo-node-app-ecs.aws.deanlofts.xyz`).

### Outputs (outputs.tf)

- `alb_arn`, `alb_dns_name`, `tg_arn`, `listener_http_arn`, `listener_https_arn`, `certificate_arn`, `record_fqdn`.

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

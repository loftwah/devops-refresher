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
terraform apply \
  -var vpc_id=$(cd ../01-vpc && terraform output -raw vpc_id) \
  -var 'public_subnet_ids=["subnet-aaaa","subnet-bbbb"]' \
  -var alb_sg_id=$(cd ../07-security-groups && terraform output -raw alb_sg_id) \
  -var certificate_domain_name=app.aws.deanlofts.xyz \
  -var hosted_zone_name=aws.deanlofts.xyz \
  -var record_name=app.aws.deanlofts.xyz \
  -var target_port=3000 \
  -var health_check_path=/healthz \
  -auto-approve
```

## Outputs

- `alb_dns_name`, `tg_arn`, `certificate_arn`, `record_fqdn`.

## Notes

- Target type `ip` for Fargate. Health checks use `/healthz`.
- ACM uses DNS validation in Route 53. Ensure the hosted zone exists for `aws.deanlofts.xyz`.

See also: `docs/decisions/ADR-001-alb-tls-termination.md` for design rationale, tradeoffs (SANs, end‑to‑end TLS), and checklist.

## Cleanup

```bash
terraform destroy -auto-approve
```

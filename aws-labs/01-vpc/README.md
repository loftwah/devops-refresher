# Lab 01 – VPC Stack Walkthrough

This document explains the “why and how” behind the VPC stack in `aws-labs/01-vpc` and ties it back to the tag strategy and acceptance criteria.

## Goals

- Create a non-default VPC with DNS enabled.
- 2 public + 2 private subnets split across exactly two AZs.
- 1 IGW, 1 NAT Gateway (in a public subnet), correct routing per subnet tier.
- Optional VPC Flow Logs wired to CloudWatch Logs (off by default).
- Consistent tagging aligned with the repo’s baseline.

## Tagging Strategy

- Provider-level `default_tags` applies `var.tags` to all resources.
- Resource-level `tags` add a clear `Name` while inheriting defaults via `merge(var.tags, { Name = ... })`.
  - Inline note: `merge(map1, map2, ...)` combines maps; when the same key exists in multiple maps, the value from the rightmost map wins. Here, `merge(var.tags, { Name = ... })` applies your baseline tags and overlays a resource-specific `Name`.
- Baseline used here matches the repo’s pattern:
  - `Owner=Dean Lofts`, `Project=devops-refresher`, `App=devops-refresher`, `Environment=staging`, `ManagedBy=Terraform`.
  - You can override or extend with `-var 'tags={...}'` or a `*.tfvars` file.

## Subnet CIDR Planning With `cidrsubnet`

We start with `var.vpc_cidr = 10.64.0.0/16`.

- We need four /20 subnets. A /20 is 4 bits “smaller” than a /16, so we set `newbits = 4`.
- We define two small maps to drive deterministic indexing:
  - `public_subnet_indices = { a = 0, b = 1 }`
  - `private_subnet_indices = { a = 2, b = 3 }`
- Why indices? It ensures stable addressing per AZ and tier without hardcoding CIDRs. This gives:
  - Public-a: `cidrsubnet(10.64.0.0/16, 4, 0)` → `10.64.0.0/20`
  - Public-b: index 1 → `10.64.16.0/20`
  - Private-a: index 2 → `10.64.32.0/20`
  - Private-b: index 3 → `10.64.48.0/20`

This pattern keeps growth headroom, guarantees no overlap, and mirrors our AZ spread.

## AZ Spread

- We use `var.azs = { a = ap-southeast-2a, b = ap-southeast-2b }`.
- Each AZ gets one public and one private subnet, satisfying HA expectations later (ALB across public subnets; ECS/EC2 in private subnets).

## Internet/NAT and Routing

- `aws_internet_gateway.this` is attached to the VPC.
- NAT placement: `aws_nat_gateway.this` resides in `public["a"]` with an Elastic IP.
- Routing:
  - Public RT default route: `0.0.0.0/0 → IGW` and associated to both public subnets.
  - Private RT default route: `0.0.0.0/0 → NAT` and associated to both private subnets.
- Staging keeps cost lower with one NAT. For production, add a NAT per AZ and split private route tables per AZ.

## Flow Logs (Toggle)

- `var.enable_flow_logs` controls whether we create an IAM role + CloudWatch Log Group + VPC Flow Log.
- Default is `false` (off). When `true`, logs go to `/aws/vpc/flow-logs/<vpc-id>`.
- Service principal for the role trust policy is `vpc-flow-logs.amazonaws.com`.

## Backend

- The backend reuses the Lab 00 state bucket and stores this stack at:
  - `staging/network/terraform.tfstate`

## Files

- `backend.tf`: S3 backend (same bucket as Lab 00).
- `providers.tf`: Uses `var.region`, `var.aws_profile`, and applies `var.tags` as default tags.
- `variables.tf`: `region`, `vpc_cidr`, `azs`, `enable_flow_logs`, `tags`.
- `main.tf`: All resources (VPC, IGW, subnets, NAT, route tables, optional Flow Logs).
- `outputs.tf`: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`.

## Acceptance Checklist

- Public RT has `0.0.0.0/0 → IGW`.
- Private RT has `0.0.0.0/0 → NAT`; no IGW route.
- Exactly two AZs; one public and one private subnet in each.
- NAT in a public subnet with an EIP; status `Available`.
- IGW attached to the same VPC.
- VPC has DNS Support + DNS Hostnames enabled.
- Flow Logs off by default, on-demand to CloudWatch when enabled.

## How to Apply

```
cd aws-labs/01-vpc
terraform init
terraform apply
```

Optionally enable flow logs:

```
terraform apply -var enable_flow_logs=true
```

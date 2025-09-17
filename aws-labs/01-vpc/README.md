# Lab 01 – VPC Stack Walkthrough

This document explains the “why and how” behind the VPC stack in `aws-labs/01-vpc` and ties it back to the tag strategy and acceptance criteria.

Related docs: `docs/vpc.md`, `docs/terraform-resource-cheatsheet.md`

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

### Why not hard-code CIDRs?

- Using indices with `cidrsubnet` keeps the plan deterministic even if you change the parent CIDR or add/remove AZs.
- It avoids manual math mistakes and overlapping ranges.
- The AZ keys (`a`, `b`, …) map cleanly to stable slots: public use the first N indices; private start at an offset.

How to pick indices generically:

- Choose child size: for /20s from a /16, `newbits = 4` (2^4 = 16 slots).
- Reserve `[0..N-1]` for public, `[N..2N-1]` for private (N = number of AZs).
- Keep keys in `var.azs` aligned with the index maps.

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

Routing mental model:

- Routes live in the subnet’s associated route table (you don’t configure both “sides” like a physical router).
- AWS provides an implicit router for intra‑VPC (`local`) traffic, and return paths for accepted traffic are handled by the fabric.
- A subnet is “public” if its route table has `0.0.0.0/0 → IGW`.

## Flow Logs (Toggle)

- `var.enable_flow_logs` controls whether we create an IAM role + CloudWatch Log Group + VPC Flow Log.
- Default is `false` (off). When `true`, logs go to `/aws/vpc/flow-logs/<vpc-id>`.
- Service principal for the role trust policy is `vpc-flow-logs.amazonaws.com`.

What Flow Logs capture (metadata only):

- Source/destination IPs and ports, protocol, direction, action (ACCEPT/REJECT), status (OK/NODATA/SKIPDATA), byte/packet counts, timestamps, ENI.
- They do not capture payloads or application‑layer details. DNS queries require Resolver query logs if needed.

Common uses:

- Troubleshoot connectivity (see ACCEPT/REJECT at the ENI).
- Security monitoring (detect scans/exfiltration) and feed to GuardDuty.
- Compliance/auditing and traffic analytics (Athena/CloudWatch dashboards).

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

## Why It Matters

- Most interview/networking issues trace back to routes, SGs vs NACLs, and NAT/east–west access. This VPC is the backbone for every later lab (ALB/ECS/RDS/Redis). Cost trade‑offs (NAT vs endpoints) and AZ spread decisions start here.

## Mental Model

- Public subnets = ingress/egress via IGW; Private subnets = egress via NAT, no direct ingress. Security Groups are stateful per‑ENI; NACLs are stateless per‑subnet and should be left default unless you have a concrete reason.
- NAT vs VPC Endpoints: NAT carries all Internet egress (billed per hour + GB). Gateway endpoints (S3/DynamoDB) are free; interface endpoints add hourly cost per AZ but let you keep AWS API traffic off the Internet and reduce NAT data charges. Start with one NAT in staging, add endpoints for high‑traffic services, and scale to per‑AZ NAT for production.

## Verification

Console checks

- VPC → Route Tables: Public RT has `0.0.0.0/0 → igw-...`; Private RT has `0.0.0.0/0 → nat-...`.
- Subnets show the expected AZs and auto‑assign public IPs disabled in private subnets.

CLI examples

```bash
# List route tables and default routes
aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=<vpc-id> \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,Routes:Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId, Nat:Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId}' \
  --output table

# Any ENIs in the VPC (proxy for active things)
aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=<vpc-id> \
  --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Status:Status,Desc:Description,Subnet:SubnetId}' --output table
```

Related endpoints lab: `aws-labs/02-vpc-endpoints/README.md`.

## Troubleshooting

- Black hole to AWS APIs from private subnets: ensure NAT is `Available`, private RT points to NAT, and VPC DNS hostnames/support are enabled. If using interface endpoints, ensure Private DNS is enabled and the endpoint SG allows 443 from your app/task ENIs.
- IMDSv2 on EC2: If you later add EC2, enforce IMDSv2 with `metadata_options { http_tokens = "required" }` and ensure apps use the v2 flow.
- SG vs NACL: Prefer SGs. NACLs can block return traffic if you add explicit denies. Reset NACLs to default allow/allow when in doubt.

## Teardown

Order matters to avoid orphaned ENIs/EIPs:

1. Destroy downstream stacks first (ECS/EKS, ALB, RDS, Redis, endpoints).
2. Delete NAT Gateway (releases EIP), then detach/delete IGW.
3. Delete non‑main route tables and subnets.
4. Finally destroy the VPC.

If `terraform destroy` fails due to ENIs in use, check:

```bash
aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=<vpc-id> \
  --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Status:Status,Attach:Attachment.InstanceId,Desc:Description}' --output table
```

## Check Your Understanding

- Why are SGs preferred over NACLs for service‑to‑service controls?
- When would you add one NAT per AZ vs rely on VPC Endpoints?
- What breaks if you disable Private DNS on an interface endpoint?

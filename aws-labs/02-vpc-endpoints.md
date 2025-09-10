# Lab 02: VPC Endpoints (Private Access to AWS Services)

## Objective

Provide private connectivity from subnets to AWS services without traversing the Internet/NAT, reducing egress costs and tightening security.

## When to Use

- Running ECS/EKS/EC2 in private subnets without a NAT Gateway
- Reducing NAT data charges for high‑volume services
- Enabling ECS Exec/SSM, CloudWatch Logs, and ECR pulls privately

## Endpoint Set (staging baseline)

- Gateway endpoints (free, route-table targets):
  - `com.amazonaws.<region>.s3` (S3)
- Interface endpoints (ENIs per AZ, billed hourly + data):
  - `ssm`, `ec2messages`, `ssmmessages` (SSM / ECS Exec)
  - `ecr.api`, `ecr.dkr` (ECR API and registry)
  - `logs` (CloudWatch Logs)
  - Optional: `secretsmanager`, `kms`, `sts`, `monitoring`, `elasticfilesystem`, `events` (as needed)

## Design

- Place interface endpoints in each AZ you use (2a/2b) and attach to the private subnets’ route tables/SGs.
- Allow the endpoints’ SG to receive from your app/task SGs (HTTPS 443).
- Keep NAT initially for simplicity; then switch workloads to endpoints progressively.

## Acceptance Criteria

- ECS tasks can pull from ECR with no Internet route.
- ECS Exec works in private subnets without NAT.
- Logs reach CloudWatch via the `logs` endpoint.
- S3 access for app buckets works via S3 Gateway endpoint (no NAT).

## Terraform Hints

- `aws_vpc_endpoint` (type `Gateway` for S3; type `Interface` for others)
- Security Group for interface endpoints allowing 443 from service/task SGs
- Associate private route tables to the S3 gateway endpoint

```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = merge(var.tags, { Name = "staging-s3-endpoint" })
}

resource "aws_security_group" "endpoints" {
  name   = "staging-vpce"
  vpc_id = aws_vpc.main.id
  ingress { from_port = 443 to_port = 443 protocol = "tcp" cidr_blocks = [var.vpc_cidr] }
  egress  { from_port = 0   to_port = 0   protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = merge(var.tags, { Name = "staging-vpce" })
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = merge(var.tags, { Name = "staging-ecr-api-vpce" })
}
```

Notes: Repeat similarly for `ecr.dkr`, `logs`, `ssm`, `ec2messages`, `ssmmessages`.

## Implementation (This Repo)

- Terraform for this lab lives in `aws-labs/02-vpc-endpoints/` and composes the VPC from Lab 01 via `terraform_remote_state`.
- State is isolated under the key `staging/network-endpoints/terraform.tfstate` in the same S3 backend as Lab 01.
- Security group `staging-vpce` allows HTTPS (443) from the VPC CIDR to the endpoints.
- Created endpoints by default:
  - Gateway: S3
  - Interface: `ssm`, `ec2messages`, `ssmmessages`, `ecr.api`, `ecr.dkr`, `logs`

Toggles you can use

- `enable_s3_gateway` (bool, default true)
- `enable_dynamodb_gateway` (bool, default false)
- `enable_secretsmanager`, `enable_kms`, `enable_sts`, `enable_monitoring`, `enable_efs`, `enable_events` (all bools, default false)
- You can also directly supply an explicit list via `interface_endpoints` and the booleans will be merged in.

How to apply

```bash
cd aws-labs/02-vpc-endpoints
terraform init
terraform apply
```

Key variables

- `region`: should match your VPC’s region (defaults to `ap-southeast-2`).
- `interface_endpoints`: list of services to enable (interface type).
- `enable_s3_gateway`: toggle S3 gateway endpoint on/off.

## Validation (Structure Only)

Full functional validation (e.g., ECR image pulls without NAT, ECS Exec over SSM) will happen in later labs once ECS/ECR are in place. For now, validate presence/configuration:

```bash
scripts/validate-vpc-endpoints.sh --profile devops-sandbox --region ap-southeast-2 --vpc-id <your-vpc-id>

# If you enabled extra endpoints, override expected list
scripts/validate-vpc-endpoints.sh --profile devops-sandbox --region ap-southeast-2 --vpc-id <your-vpc-id> \
  --expect ssm,ec2messages,ssmmessages,ecr.api,ecr.dkr,logs,secretsmanager
```

This script checks:

- S3 gateway endpoint exists and is type `Gateway`, and shows associated route tables.
- Interface endpoints exist for the expected services, are type `Interface`, and have Private DNS enabled.

Limitations

- Does not perform data‑plane tests (ECR pulls, ECS Exec). Those are covered once services are deployed in later labs.

## Walkthrough

What we build

- Import the VPC ID and private subnet IDs from Lab 01 via `terraform_remote_state`.
- Create a security group `staging-vpce` that allows HTTPS (443) from the VPC CIDR to the endpoints.
- Create a gateway endpoint for S3 (optional) and interface endpoints for common services you’ll use from private subnets.
- Keep NAT in place for now; migrate traffic service-by-service to these endpoints to reduce egress and tighten security.

Tasks (Do These)

1. Wire in VPC remote state (consumes `vpc_id`, `private_subnet_ids`).
2. Discover the private route table by `Name` tag `staging-private-rt` from Lab 01.
3. Create `staging-vpce` SG: inbound 443 from the VPC CIDR; outbound all.
4. Create S3 gateway endpoint (associates to the private route table) if enabled.
5. Create interface endpoints across all private subnets for selected services (ECR, Logs, SSM, etc.).
6. Output endpoint IDs and the SG for downstream stacks (e.g., allow 443 from app/task SGs to `staging-vpce` if you want extra isolation).

How to apply

```bash
cd aws-labs/02-vpc-endpoints
terraform init
terraform apply \
  -var 'enable_secretsmanager=true' \
  -var 'enable_kms=true'
```

How to check (Console)

- VPC → Endpoints: confirm expected list; type is Gateway for S3/DynamoDB, Interface for others; Private DNS Enabled = true for interface endpoints.
- Click each interface endpoint → Subnets tab: two subnets (2a/2b); Security groups includes `staging-vpce`.
- VPC → Route Tables → `staging-private-rt`: Routes tab shows `com.amazonaws.<region>.s3` target when S3 gateway endpoint is enabled.

## Toggles and Scenarios

Guiding principle: keep defaults lean for cost and clarity; turn on only what a workload actually uses. You can still keep NAT as a fallback while adopting endpoints incrementally.

- `enable_s3_gateway` (default: true)
  - Why: S3 is ubiquitous (logs, artifacts, app data). Gateway endpoints are free and route-table based.
  - When false: if you truly do not access S3 from private subnets.

- `enable_dynamodb_gateway` (default: false)
  - Why: Only for apps calling DynamoDB from private subnets; otherwise skip to avoid clutter.

- Interface endpoints (created via either `interface_endpoints` list or the boolean toggles below). All are billed per-AZ hour + data processed.
  - Defaults included: `ssm`, `ec2messages`, `ssmmessages`, `ecr.api`, `ecr.dkr`, `logs`.
    - Rationale: covers ECS Exec/SSM, ECR pulls, and CloudWatch Logs for most containerized apps.
  - `enable_secretsmanager` (default: false)
    - Enable when: your app reads secrets at runtime from Secrets Manager (good for demos to “show it off”).
  - `enable_kms` (default: false)
    - Enable when: your app or CI decrypts data with KMS (envelope decryption, S3 SSE‑KMS, Secrets retrieval using KMS). Nice for demos alongside Secrets Manager.
  - `enable_sts` (default: false)
    - Enable when: workloads call STS APIs (AssumeRole) directly and you want those calls private. Many ECS/EC2 role use-cases work without this, so keep off unless needed.
  - `enable_monitoring` (default: false)
    - CloudWatch Metrics/Monitoring API. Turn on if apps post custom metrics or you run private metric collection.
  - `enable_efs` (default: false)
    - EFS API endpoint. Not required for mounting (that uses mount targets), but enable if you interact with the EFS API from private subnets.
  - `enable_events` (default: false)
    - EventBridge (events) API. Enable if you publish/consume events from private subnets.

Notes on `interface_endpoints`

- You can supply an explicit list in `interface_endpoints`. The boolean toggles are merged in; duplicates are de‑duplicated.
- Service name mapping is `com.amazonaws.<region>.<suffix>` (e.g., `ecr.api`, `logs`, `ssm`).

## Cost and Trade‑offs

- Gateway endpoints: free (control plane). Easy win for S3 (and DynamoDB when needed).
- Interface endpoints: hourly + data charges per AZ per endpoint. Start with the defaults (SSM/ECR/Logs) and add others only when used.
- You can keep NAT initially for simplicity, then tighten egress later once endpoints cover your paths.

## Gotchas / Tips

- Private DNS: must be enabled on interface endpoints so SDKs resolve to the VPC endpoints automatically.
- Security groups: the provided SG allows 443 from the whole VPC. For stricter security, allow 443 only from your app/task SGs and attach those SGs to the endpoints.
- Route tables: gateway endpoints must be associated to the private route tables to take effect.
- Region consistency: set `var.region` to match the VPC’s region.
- Validation: current script checks presence/config only; functional tests (ECR pulls, ECS Exec, logs) land in later labs.

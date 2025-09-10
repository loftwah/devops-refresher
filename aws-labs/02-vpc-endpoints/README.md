# Lab 02: VPC Endpoints (Private Access to AWS Services)

Provide private connectivity from your private subnets to AWS services without traversing the Internet/NAT. This reduces egress cost and tightens security while enabling services like ECS Exec, ECR pulls, and CloudWatch Logs from private subnets.

## Decisions (Locked)

- Region/AZs: reuse the same region and AZs as Lab 01.
- Scope: add endpoints to the existing VPC from Lab 01 via remote state (no VPC changes here).
- Defaults: lean by default; enable only common, high‑value endpoints.
  - Gateway: S3 (ON by default), DynamoDB (OFF)
  - Interface: SSM/Exec, ECR, CloudWatch Logs (ON); Secrets Manager, KMS, STS, Monitoring, EFS, EventBridge (OFF)

## Objectives

- Create S3 Gateway endpoint and associate it with the private route table (optional toggle).
- Create Interface endpoints in each AZ for selected services across the private subnets.
- Attach a shared endpoint Security Group allowing HTTPS (443) from the VPC CIDR.
- Keep state isolated from Lab 01 but consume its outputs (VPC ID, private subnet IDs).

## Quick Mental Model (What/Why)

- Gateway endpoints (S3/DynamoDB): route table targets, free, no ENIs.
- Interface endpoints (most others): ENIs per AZ, billed hourly + data, require SGs; Private DNS makes SDKs resolve to the endpoint automatically.
- Strategy: keep NAT initially → add endpoints for critical services → optionally restrict egress later.

Required vs Optional

- Required: Endpoint SG (`staging-vpce`), Interface endpoints for SSM/ECR/Logs in private subnets.
- Optional: S3 Gateway (recommended), DynamoDB Gateway, additional interface endpoints (Secrets Manager, KMS, STS, Monitoring, EFS, Events).

## Tasks (Do These)

1. Read VPC outputs from Lab 01 via `terraform_remote_state` (VPC ID, private subnet IDs).
2. Discover the private route table via tag `Name=staging-private-rt` (from Lab 01).
3. Create `staging-vpce` security group: allow 443 from the VPC CIDR; allow all egress.
4. Create S3 Gateway endpoint (toggle `enable_s3_gateway`) and associate to the private route table.
5. Create Interface endpoints across the private subnets for the selected services; enable Private DNS.
6. Output endpoint IDs and the endpoint SG for downstream stacks/visibility.

## Acceptance Criteria (Validate Explicitly)

- S3 Gateway endpoint exists (when enabled) and is type `Gateway`; associated with the private route table.
- Interface endpoints for `ssm`, `ec2messages`, `ssmmessages`, `ecr.api`, `ecr.dkr`, `logs` exist (by default), are type `Interface`, and have Private DNS enabled.
- Each interface endpoint is present in both private subnets (2a/2b) and attached to `staging-vpce` SG.
- No changes are made to the VPC core (subnets, NAT, IGW) in this lab.

How to check (Console/Terraform)

- Console → VPC → Endpoints: verify expected types, Private DNS = true, subnets include your 2 private subnets, SG includes `staging-vpce`.
- Console → Route Tables → `staging-private-rt`: when S3 is enabled, confirm the S3 route target appears.
- Terraform: `terraform output` shows `endpoint_sg_id`, `s3_gateway_endpoint_id` (nullable), and a map of `interface_endpoint_ids`.

## Terraform Files

- `backend.tf`: separate state under `staging/network-endpoints/terraform.tfstate` in the same S3 bucket used by Lab 01.
- `providers.tf`: region/profile defaults + provider `default_tags`.
- `variables.tf`: backend config for Lab 01 state + endpoint toggles.
- `main.tf`: remote state import, SG, gateway endpoints, interface endpoints.
- `outputs.tf`: endpoint SG and endpoint IDs.

## Variables (Key)

- `region` (string): must match Lab 01 region. Default `ap-southeast-2`.
- `vpc_state_bucket`/`vpc_state_key`/`vpc_state_region`: where Lab 01 state lives.
- `private_route_table_name` (string): default `staging-private-rt`.
- Gateway toggles:
  - `enable_s3_gateway` (bool, default true)
  - `enable_dynamodb_gateway` (bool, default false)
- Interface endpoints list + convenience toggles:
  - `interface_endpoints` (list of suffixes) merged with toggles below
  - `enable_secretsmanager`, `enable_kms`, `enable_sts`, `enable_monitoring`, `enable_efs`, `enable_events` (bools, default false)

Notes:

- Service name is `com.amazonaws.${var.region}.<suffix>`; examples: `ecr.api`, `logs`, `ssm`.
- The final set is de‑duplicated when merging the explicit list with toggles.

## Outputs for Downstream Stacks

- `endpoint_sg_id` – Security group used by interface endpoints.
- `s3_gateway_endpoint_id` – ID (nullable) of the S3 gateway endpoint.
- `interface_endpoint_ids` – Map from service suffix → endpoint ID.

## Workflow

- `terraform init`
- Enable any desired toggles via `-var` flags, e.g.:
  - `terraform apply -var 'enable_secretsmanager=true' -var 'enable_kms=true'`

## Toggles and When to Use

Lean defaults for cost/clarity. Turn on what your workloads actually use. Keep NAT during adoption; tighten later.

- `enable_s3_gateway` (default: true)
  - Use for S3 access from private subnets. Gateway endpoints are free and reduce NAT egress.
- `enable_dynamodb_gateway` (default: false)
  - Enable only if your apps call DynamoDB from private subnets.
- Interface (billed per AZ + data):
  - Defaults: `ssm`, `ec2messages`, `ssmmessages` (SSM/ECS Exec), `ecr.api`, `ecr.dkr` (ECR pulls), `logs` (CloudWatch Logs)
  - `enable_secretsmanager` (false): turn on for apps that read secrets at runtime; great for demos.
  - `enable_kms` (false): enable if apps/CI perform KMS decrypt or use SSE‑KMS; often paired with Secrets Manager in demos.
  - `enable_sts` (false): for explicit STS API usage (AssumeRole) from private subnets.
  - `enable_monitoring` (false): CloudWatch metrics/monitoring APIs for custom metrics.
  - `enable_efs` (false): EFS API access (not required for mounting).
  - `enable_events` (false): EventBridge API when publishing/consuming events privately.

## Validation (Structure Only)

Functional checks depend on later labs (ECS/ECR/Logs). For now, validate presence/config:

```bash
scripts/validate-vpc-endpoints.sh \
  --profile devops-sandbox \
  --region ap-southeast-2 \
  --vpc-id <your-vpc-id>

# If you enabled extras, override expected list
scripts/validate-vpc-endpoints.sh \
  --profile devops-sandbox \
  --region ap-southeast-2 \
  --vpc-id <your-vpc-id> \
  --expect ssm,ec2messages,ssmmessages,ecr.api,ecr.dkr,logs,secretsmanager
```

## Hints

- Private DNS must be enabled on interface endpoints so SDKs resolve privately.
- For stricter security, lock endpoint SG ingress to your app/task SG instead of VPC‑wide.
- Associate gateway endpoints to private route tables or they won’t take effect.
- Keep endpoint selection minimal in staging; expand as demos or needs require (e.g., enable `secretsmanager` and `kms` to “show them off”).

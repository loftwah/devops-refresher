# VPC Endpoints (Private Access to AWS Services)

Build private connectivity from your private subnets to AWS services so traffic stays inside AWS networks, reducing NAT egress and improving security.

## Decisions (Locked)

- Keep NAT initially; add endpoints now and migrate traffic progressively.
- Region/AZs: reuse from Lab 01 (`ap-southeast-2`, AZs `2a`, `2b`).
- Baseline endpoints for staging: S3 (Gateway), SSM/Exec, ECR, CloudWatch Logs (Interface). Others are optional per‑need.

## Objectives

- Add an S3 Gateway endpoint associated to the private route table (optional toggle).
- Add Interface endpoints in both private subnets for selected services: SSM/Exec, ECR, Logs (defaults) plus optional extras.
- Allow HTTPS (443) from your workloads to the endpoints via an endpoint security group.

## Quick Mental Model (What/Why)

- Gateway endpoints (S3/DynamoDB): free, route‑table targets, no ENIs.
- Interface endpoints (most others): ENIs per AZ, billed hourly + data; require SGs; enable Private DNS so SDKs resolve privately.
- Strategy: start with the defaults (SSM, ECR, Logs) to support container ops without Internet.

Required vs Optional

- Required (staging baseline): S3 (Gateway), `ssm`, `ec2messages`, `ssmmessages`, `ecr.api`, `ecr.dkr`, `logs` (Interface).
- Optional (enable when used): `secretsmanager`, `kms`, `sts`, `monitoring`, `elasticfilesystem`, `events`, and DynamoDB (Gateway).

## Tasks (Do These)

1. Enable S3 Gateway endpoint and associate it to the private route table.
2. Enable Interface endpoints across both private subnets for: `ssm`, `ec2messages`, `ssmmessages`, `ecr.api`, `ecr.dkr`, `logs`.
3. Configure Private DNS on interface endpoints so SDKs resolve to the VPCE addresses.
4. Use a shared endpoint Security Group that allows HTTPS from your workloads.
5. Optionally enable extras (e.g., `secretsmanager`, `kms`) if your app/demo uses them.

## Acceptance Criteria (Validate Explicitly)

- S3: Gateway endpoint present (if enabled) and attached to the private route table.
- Interface endpoints: present for the selected services, type = Interface, Private DNS = true, present in both private subnets, attached to an SG that allows 443 from workloads.
- No public Internet route is required for SSM/ECR/Logs operations once workloads are pointed at endpoints.

## How to Check (Console/CLI)

- Console → VPC → Endpoints: verify type, Private DNS, Subnets (2 private), and SG references.
- Console → Route Tables → private table: S3 prefix list route appears when S3 Gateway is enabled.
- Script (structure‑only): `aws-labs/scripts/validate-vpc-endpoints.sh --profile devops-sandbox --region ap-southeast-2 --vpc-id <vpc-id>`
  - If you enabled extras, pass them: `--expect ssm,ec2messages,ssmmessages,ecr.api,ecr.dkr,logs,secretsmanager`

## Toggles (When to Use)

- S3 Gateway (default ON): almost always useful from private subnets; reduces NAT egress.
- DynamoDB Gateway (default OFF): enable only if your app uses DynamoDB from private subnets.
- Interface defaults: SSM/Exec, ECR, Logs — enable to support ECS/EKS/EC2 in private subnets.
- Secrets Manager (OFF) + KMS (OFF): enable together if demonstrating secret retrieval or KMS decrypt from private subnets.
- STS (OFF): enable for explicit AssumeRole/API usage from private subnets.
- Monitoring (OFF): enable if pushing custom CloudWatch metrics privately.
- EFS (OFF): API access; not required for mounting via mount targets.
- Events (OFF): EventBridge API for private publish/consume.

## Notes

- Functional validation (e.g., ECR pulls without NAT, ECS Exec) lands in later labs when workloads exist; this lab focuses on presence/config.
- Keep NAT for now; once endpoints cover traffic, you can tighten egress policies.

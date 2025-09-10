# Lab 12: VPC Endpoints (Private Access to AWS Services)

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
  - Optional: `secretsmanager`, `kms`, `sts`, `monitoring` (as needed)

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

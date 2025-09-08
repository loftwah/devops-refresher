# Lab 01: Networking (VPC + Subnets)

## Objectives

- Create a VPC with 2 public and 2 private subnets across AZs, with IGW, NAT, and routes.
- Store Terraform state in the existing S3 backend created in Lab 00.

## Tasks

1. Define `aws_vpc`, `aws_internet_gateway`.
2. Create 2 public + 2 private subnets with distinct AZs.
3. Add `aws_nat_gateway` (one is fine for staging) and route tables.
4. Tag everything with `Environment = staging`.
5. Output `vpc_id`, `public_subnet_ids`, `private_subnet_ids` for downstream stacks (ALB, ECS, RDS, etc.).

## Acceptance Criteria

- Public subnets route 0.0.0.0/0 via IGW; private via NAT.
- Subnets distributed across two AZs.
- Terraform uses the same S3 backend bucket as Lab 00 with a unique key (e.g., `staging/network/terraform.tfstate`).

## Hints

- Use Terraform `for_each` to generate subnets and route tables.
- Consider AWS VPC IP addressing patterns that won’t collide later.

## Using the Existing Remote State Backend

- Reuse the S3 bucket created in Lab 00 (see `aws-labs/00-backend-bootstrap` output `state_bucket_name`).
- Give this VPC stack its own key to keep states isolated. Example:

```hcl
// backend.tf
terraform {
  required_version = ">= 1.13.0"
  backend "s3" {
    bucket       = "tf-state-<account>-<region>"       // e.g., tf-state-139294524816-us-east-1
    key          = "staging/network/terraform.tfstate" // choose a clear prefix per env/domain
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

Workflow:
- `terraform init` (configures backend and creates the state object if not present)
- `terraform apply`

## Building Toward ECS

- This repo grows into a production‑style ECS environment. Recommended stack order and state keys:
  - Bootstrap: `bootstrap/global/terraform.tfstate` (already done)
  - Network (this lab): `staging/network/terraform.tfstate`
  - ALB + Security Groups: `staging/alb/terraform.tfstate`
  - ECR: `staging/ecr/terraform.tfstate`
  - ECS Cluster/Service/Tasks: `staging/ecs/terraform.tfstate`

Expose VPC outputs here so downstream stacks can consume them. Example outputs:

```hcl
output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = [for s in aws_subnet.public : s.id] }
output "private_subnet_ids" { value = [for s in aws_subnet.private : s.id] }
```

Downstream stacks can import these via `terraform_remote_state`:

```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "tf-state-<account>-<region>"
    key    = "staging/network/terraform.tfstate"
    region = "us-east-1"
  }
}

// Example usage
locals {
  vpc_id            = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}
```

Notes:
- Keep one bucket per account/region and separate states by `key` prefixes for each domain/environment.
- Backend keys can’t use variables/locals; set them explicitly and consistently.

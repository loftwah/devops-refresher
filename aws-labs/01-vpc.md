# Lab 01: Networking (VPC + Subnets)

## Objectives

- Create a VPC with 2 public and 2 private subnets across AZs, with IGW, NAT, and routes.

## Tasks

1. Define `aws_vpc`, `aws_internet_gateway`.
2. Create 2 public + 2 private subnets with distinct AZs.
3. Add `aws_nat_gateway` (one is fine for staging) and route tables.
4. Tag everything with `Environment = staging`.

## Acceptance Criteria

- Public subnets route 0.0.0.0/0 via IGW; private via NAT.
- Subnets distributed across two AZs.

## Hints

- Use Terraform `for_each` to generate subnets and route tables.
- Consider AWS VPC IP addressing patterns that won’t collide later.

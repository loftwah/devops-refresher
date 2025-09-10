# Lab 01: Networking (VPC + Subnets)

Build a minimal, production-shaped VPC for staging. Keep it simple and explicit.

## Decisions (Locked)

- Region/AZs: `ap-southeast-2` → `2a`, `2b`
- VPC CIDR (non-default): `10.64.0.0/16`
- Subnets (/20s):
  - Public-a: `10.64.0.0/20`, Public-b: `10.64.16.0/20`
  - Private-a: `10.64.32.0/20`, Private-b: `10.64.48.0/20`
- Flow Logs: wired but OFF by default (CloudWatch Logs when enabled)
- Tag baseline: `Environment=staging`, `ManagedBy=Terraform` (+ add `Project/Owner/CostCenter` as needed)

## Objectives

- Create one VPC with 2 public and 2 private subnets across two AZs.
- Add one Internet Gateway (IGW), one NAT Gateway (ok for staging), and route tables.
- Store Terraform state in the existing S3 backend from Lab 00.

## Quick Mental Model (What/Why)

- VPC: Your private network in AWS. Enable DNS hostnames/support.
- Public subnets: Face the internet (via IGW). Host internet-facing ALB and the NAT.
- Private subnets: No direct internet. Outbound goes to NAT for updates, pulls, APIs. Host ECS/EC2.
- IGW: Doorway to the internet for public subnets.
- NAT Gateway: Lets private subnets reach the internet without being reachable from it.
- Route tables: Tell each subnet where `0.0.0.0/0` goes (IGW for public; NAT for private).

Required vs Optional

- Required: 1 VPC, 2 public subnets, 2 private subnets, 1 IGW, route tables, 1 NAT GW (for staging), tagging.
- Optional: 1 NAT per AZ (best practice/HA; higher cost). VPC Endpoints come later (not in this lab).

## Tasks (Do These)

1. Create `aws_vpc` with DNS hostnames/support enabled and a sensible CIDR (e.g., `10.0.0.0/16`).
2. Create 2 public subnets and 2 private subnets, spread across two AZs (e.g., `a` and `b`).
3. Create and attach an `aws_internet_gateway` to the VPC.
4. Create one `aws_nat_gateway` in a public subnet (allocate an Elastic IP).
5. Create one route table for public subnets: add `0.0.0.0/0 -> igw-...`; associate to both public subnets.
6. Create one route table for private subnets: add `0.0.0.0/0 -> nat-...`; associate to both private subnets.
7. Tag all resources with `Environment = staging` and clear names.
8. Output `vpc_id`, `public_subnet_ids`, `private_subnet_ids` for downstream stacks.

Notes on AZs and CIDRs

- Distribute: Put one public + one private subnet in each AZ.
- CIDRs: Use non-overlapping ranges (e.g., `10.0.0.0/20` public-a, `10.0.16.0/20` public-b, `10.0.32.0/20` private-a, `10.0.48.0/20` private-b). Adjust to your scheme.

## Acceptance Criteria (Validate Explicitly)

- Routes: Public route table has `0.0.0.0/0 -> IGW`. Private route table has `0.0.0.0/0 -> NAT`. No IGW route on private tables.
- AZ spread: Exactly two AZs used; each has one public and one private subnet.
- NAT placement: NAT is in a public subnet and has an Elastic IP.
- IGW: IGW is attached to the same VPC.
- DNS: VPC has DNS Hostnames + DNS Support enabled.
- Backend: Terraform uses the same S3 bucket as Lab 00 with a unique key, e.g., `staging/network/terraform.tfstate`.

How to check (Console/Terraform)

- Console → VPC → Subnets: confirm AZs and tags; open each subnet’s Route Table and verify the default route target (IGW for public; NAT for private).
- Console → VPC → NAT Gateways: status Available; Subnet is public; Elastic IP attached.
- Console → VPC → Internet Gateways: state Attached; VPC matches.
- Terraform: `terraform output` shows `vpc_id`, `public_subnet_ids`, `private_subnet_ids` lists with 2 entries each.

## Hints

- Use `for_each` with a map of AZ suffixes and names to create subnets/associations.
- Use `cidrsubnet(var.vpc_cidr, <newbits>, <index>)` to carve subnet CIDRs deterministically.
- One NAT for staging keeps cost low; for prod, prefer one NAT per AZ and separate private route tables per AZ.

## Remote State Backend (Reuse Lab 00)

- Reuse the S3 bucket from Lab 00. Give this stack its own key to keep states isolated.

Example `backend.tf`:

```hcl
terraform {
  required_version = ">= 1.13.0"
  backend "s3" {
    bucket       = "tf-state-<account>-<region>"       # e.g., tf-state-139294524816-us-east-1
    key          = "staging/network/terraform.tfstate" # explicit per env/domain
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

Workflow

- `terraform init` (configures backend/creates state object)
- `terraform apply`

Notes

- Keep one bucket per account/region; separate by `key` prefixes per env/domain.
- Backend keys cannot use variables/locals; set them explicitly.

## Outputs for Downstream Stacks

Expose these from this stack:

```hcl
output "vpc_id"            { value = aws_vpc.main.id }
output "public_subnet_ids"  { value = [for s in aws_subnet.public  : s.id] }
output "private_subnet_ids" { value = [for s in aws_subnet.private : s.id] }
```

Import in downstream stacks via `terraform_remote_state`:

```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "tf-state-<account>-<region>"
    key    = "staging/network/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}
```

Recommended state keys (path → purpose)

- `bootstrap/global/terraform.tfstate` → already done
- `staging/network/terraform.tfstate` → this lab
- `staging/alb/terraform.tfstate` → ALB + Security Groups
- `staging/ecr/terraform.tfstate` → ECR
- `staging/ecs/terraform.tfstate` → ECS Cluster/Service/Tasks

## Pre-flight Checks (Document, Don’t Skip)

Before creating anything, inventory existing VPCs and check usage/limits to avoid clashes:

Quick inventory

```bash
# List all VPCs (count + IDs, whether default)
aws ec2 describe-vpcs \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,IsDefault:IsDefault,State:State}' \
  --output table

# Count
aws ec2 describe-vpcs --query 'length(Vpcs[])'

# For each VPC, see if DNS is on
aws ec2 describe-vpc-attribute --vpc-id <vpc-id> --attribute enableDnsSupport
aws ec2 describe-vpc-attribute --vpc-id <vpc-id> --attribute enableDnsHostnames
```

“Are we using these VPCs?” sanity checks

```bash
# Any ENIs in each VPC (proxy for activity)
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Status:Status,Subnet:SubnetId,Description:Description}' \
  --output table

# Instances by VPC
aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,Subnet:SubnetId}' \
  --output table

# NAT GWs / IGWs present
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>" --query 'NatGateways[].NatGatewayId'
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=<vpc-id>" --query 'InternetGateways[].InternetGatewayId'

# Subnets in each VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[].{Id:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,PublicMapIp:MapPublicIpOnLaunch}' \
  --output table

# Flow Logs on/off
aws ec2 describe-flow-logs --filter "Name=resource-id,Values=<vpc-id>" \
  --query 'FlowLogs[].{Id:FlowLogId,Status:FlowLogStatus,Dest:LogDestination,Format:LogFormat}' \
  --output table
```

Note: You do not need to run these as part of the lab to pass; they’re here to validate limits and avoid CIDR collisions if you already have VPCs.

# Cloud Engineer Checklist (AU DevOps)

Core Signals

- Secure AWS foundations: accounts, VPC, subnets, routing, endpoints
- IAM design, least privilege, secrets, logging/audit (CloudTrail)
- Core services: ECR, ECS/EKS, RDS, ALB, ElastiCache, Route 53
- IaC (Terraform) with modules, environments, remote state

Portfolio Evidence From This Repo

- Terraform backend/state: `aws-labs/00-backend-terraform-state/`
- VPC + Endpoints: `aws-labs/01-vpc/`, `aws-labs/02-vpc-endpoints/`
- IAM + SGs: `aws-labs/06-iam/`, `aws-labs/07-security-groups/`, `docs/iam.md`, `docs/security-groups.md`
- ECR + ECS + RDS: `aws-labs/03-ecr/`, `aws-labs/14-ecs-service/`, `aws-labs/09-rds/`
- ALB + DNS + TLS: `aws-labs/12-alb/`, `aws-labs/05-dns-route53.md`, `docs/decisions/ADR-001-alb-tls-termination.md`
- CloudFront and networking notes: `aws-labs/99-cloudfront.md`, `docs/vpc.md`, `docs/cloudtrail.md`

Interview Prep Focus

- Multi-account patterns, landing zone basics, centralised logging
- Private networking patterns with endpoints/NAT; SG rules rationale
- Database HA/backup/rotation; secret rotation runbooks
- Migrating workloads from ECS→EKS (trade-offs)

ATS Keywords

- AWS, VPC, Subnets, Route 53, IAM, Security Groups, CloudTrail, Terraform, ECS, EKS, ECR, RDS, ALB, ElastiCache, TLS

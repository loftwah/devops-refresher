# Labs Roadmap and Decisions

This repo’s labs build a staging-ready stack step by step. This document captures decisions and the sequence so you can jump in at any point.

## Sequence

1. 00-backend-bootstrap – Create secure S3 bucket for state
2. 00-backend-terraform-state – Configure backend + provider defaults
3. 01-vpc – VPC, subnets, IGW/NAT, routes, flow logs (toggle)
4. 02-vpc-endpoints – Private access (SSM, ECR, Logs, S3)
5. 03-ecr – ECR repos, lifecycle, scanning, mirrors
6. 04-demo-app – Single repo (TS/Express), CRUD S3/Postgres/Redis, Dockerfile, buildspecs (implemented in https://github.com/loftwah/demo-node-app; includes boot-time self-test that logs CRUD across all services)
7. 05-s3 – App bucket for object CRUD (permissions for app)
8. 06-rds-postgres – Postgres instance + SGs
9. 07-elasticache-redis – Redis (ElastiCache) + SGs
10. 08-ecs – Cluster, service, task roles, SGs, deploy demo app
11. 09-dns-route53 – Hosted zone `aws.deanlofts.xyz`, records
12. 10-cicd – CodeStar connection, CodeBuild, CodePipeline (Terraform in `10-cicd-infra/`)
13. 11-eks – Cluster, ALB Ingress, external-dns, Helm chart deploy
14. 12-logging-metrics – CloudWatch logs/metrics/dashboards
15. 13-alb – Application Load Balancer
16. 14-cloudfront – CDN in front of ALB/S3 with TLS
17. 15-parameter-store – SSM parameters and app wiring
18. 16-fault-labs – Troubleshooting scenarios (ECS/EKS)

## Cross-Cutting Decisions

- Tags baseline via provider default_tags; add Name via `merge(var.tags, { Name = ... })`.
- State in us-east-1 S3 bucket; resources can be in other regions.
- Public base images: prefer ECR Public; for others, use ECR Pull Through Cache.
- DNS: delegate `aws.deanlofts.xyz` to Route 53; use ALB aliases and external-dns.
- Secrets: use Secrets Manager; config: use SSM Parameter Store.
- Access: prefer SSM Session Manager; no public SSH.

## Scripts

- `scripts/validate-backend.sh` – backend checks
- `scripts/validate-vpc.sh` – VPC acceptance checks
- `scripts/validate-vpc-endpoints.sh` – VPC endpoints structure checks
- `scripts/ecs-logs.sh`, `scripts/ecs-exec.sh` – ECS troubleshooting
- `scripts/eks-logs.sh`, `scripts/eks-exec.sh` – EKS troubleshooting
- `scripts/validate-delegation.sh` – DNS subdomain delegation check

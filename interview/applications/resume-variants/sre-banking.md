# Resume Variant: SRE (Banking/FSI, Melbourne)

Name | Melbourne, VIC | Email | Mobile | LinkedIn | GitHub

Headline

- SRE (SLOs/SLIs, Incident Response, AWS EKS, Terraform, CI/CD)

Summary

- SRE focused on reliability and auditability in regulated environments. Defined SLOs, reduced incident volume and MTTR, and codified controls in Terraform. Melbourne-based; designed for `ap-southeast-4` with DR to `-2`.

Core Skills

- AWS (EKS, ALB, RDS, ElastiCache), Terraform, Prometheus/Grafana, GitHub Actions/CodeBuild, Runbooks, Incident Command, Blue/Green & Canary, IAM/SGs, CloudTrail

Experience (Repo-anchored)
Project Portfolio | 2024–Present

- Implemented Prometheus/Grafana with SLOs and alert routing; cut Sev‑1s by 40% (aws-labs/16-observability, docs/runbooks/\*).
- Codified IAM/SG baselines and CloudTrail evidence in Terraform (aws-labs/06-iam, 07-security-groups, docs/cloudtrail.md).
- Shipped safe deploys to EKS via Helm with ALB; rollback under 5 minutes (aws-labs/18-eks-alb-externaldns, demo-node-app/deploy/eks/chart/).
- Authored ADRs clarifying TLS termination, pipeline ownership, artifact controls (docs/decisions/ADR-001, 004, 005, 006, 007).

Projects

- EKS + CI/CD with DR plan (primary `ap-southeast-4`, DR `-2`), runbooked failover tests.

Keywords

- SRE, SLO, SLI, Error Budget, Prometheus, Grafana, Runbooks, Incident Response, EKS, Terraform, IAM, Security Groups, CloudTrail, Blue/Green, Canary, Melbourne

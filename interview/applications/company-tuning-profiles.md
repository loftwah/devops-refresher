# Company Tuning Profiles (AU + Global)

Use these to tailor resume bullets, LinkedIn, and answers. Always verify current expectations via recent JDs.

## Commonwealth Bank (Banking, AU)

- What: risk, auditability, DR, change control, segregation of duties.
- Where (repo): CloudTrail (`docs/cloudtrail.md`), SG/IAM (`docs/security-groups.md`, `docs/iam.md`), Terraform state (`aws-labs/00-backend-terraform-state/`), ALB/TLS (`docs/decisions/ADR-001-alb-tls-termination.md`).
- Why: regulated environment; evidence and traceability.
- How (bullet): “Codified IAM/SG baselines and CloudTrail evidence capture in Terraform; enabled audit-ready change logs and reduced exceptions.”
- Melbourne note: emphasise `ap-southeast-4` with DR to `-2`, and change windows.

## Bunnings (Retail, AU)

- What: cost efficiency, scalability for spikes, simplicity for distributed teams.
- Where: CI/CD templating (`aws-labs/20-cicd-eks-pipeline/`), ALB/ExternalDNS (`aws-labs/18-eks-alb-externaldns/`), observability (`aws-labs/16-observability/`).
- Why: lots of services, need paved paths and predictable ops.
- How: “Templated CI/CD and Helm deploys; added autoscaling and cached ingress; improved release safety and cost visibility.”

## Telstra (Telco, AU)

- What: network boundaries, HA, incident response, change management.
- Where: VPC/Endpoints (`aws-labs/01-vpc`, `02-vpc-endpoints`), ALB/TLS (`12-alb/` + ADR), runbooks (`docs/runbooks/*`).
- Why: large networked estates; reliability first.
- How: “Designed ALB‑backed blue/green on EKS with runbooks; reduced change failure rate and improved MTTR.”

## Atlassian (Product Platform, AU)

- What: developer experience, paved paths, policy-as-code, tenancy isolation.
- Where: EKS (`17-eks-cluster`), OPA/policies (`aws-labs/kubernetes/policies/`), CI/CD to EKS (`20-cicd-eks-pipeline`), Helm (`kubernetes/helm/demo-app`).
- Why: empower teams to ship safely and quickly.
- How: “Built paved paths on EKS with Terraform modules, IRSA, OPA, and canary deploys; reduced lead time while keeping prod safe.”

## Canva (Scale-up, AU)

- What: simplicity, speed, user impact, SLOs and observability.
- Where: Observability (`16-observability`), CD strategies (ALB + Helm), ADRs.
- Why: move fast with reliability.
- How: “Implemented SLOs/SLIs and autoscaling; cut Sev‑1s and improved p95 latency; safe rollbacks via Helm canaries on ALB.”

## AWS (Cloud Provider, AU + Global)

- What: deep AWS patterns, well-architected, IaC, security, customer obsession.
- Where: Terraform modules across networking, IAM, compute; ADRs and runbooks showing trade-offs and ownership.
- Why: bar-raiser style interviews; clarity and trade-off thinking.
- How: “Designed multi-account foundations with Terraform; documented guardrails and incident response; improved change safety with pipelines and policy.”

## CrowdStrike (Security, Global)

- What: production hardening, observability, incident response, secure build chain.
- Where: IAM/SG (`docs/iam.md`, `docs/security-groups.md`), CI/CD + validation (`docs/validation-strategy.md`), container images (`demo-node-app/Dockerfile`).
- Why: security-first culture; measurable risk reduction.
- How: “Hardened pipelines with image scanning and provenance patterns; tightened least-privilege IAM and SG baselines; actionable alerting.”

## Also Consider (AU)

- Xero, REA Group, NAB/ANZ/Westpac, Coles/Woolworths, CSIRO — tune using the sector guidance above.

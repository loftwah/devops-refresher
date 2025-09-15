# Site Reliability Engineer Checklist (AU DevOps)

Core Signals

- SLO/SLI definition, alerting strategy, error budgets, incident response
- Production readiness reviews, release safety, chaos/resilience mindset
- Observability platform ownership; actionable alerts; MTTR reduction
- Pragmatic automation for on-call toil reduction

Portfolio Evidence From This Repo

- Observability stack + docs: `aws-labs/16-observability/`, `docs/eks-overview.md`
- Runbooks: `docs/runbooks/*` (rotate secrets, CI/CD IAM, Terraform import)
- CI/CD reliability decisions: `docs/decisions/ADR-004-buildspec-location.md`, `ADR-005-cicd-iam-ownership.md`, `ADR-006-artifacts-bucket-policy-ownership.md`
- EKS logs and validation scripts: `aws-labs/scripts/eks-logs.sh`, `validate-eks-cluster.sh`
- ALB TLS and SG decisions: `docs/decisions/ADR-001-alb-tls-termination.md`, `docs/security-groups.md`

Interview Prep Focus

- Define SLIs for API on EKS, set SLOs; alerting without noise
- Incident walkthrough: detection → mitigation → RCA → prevention
- Deploy safety: canary vs blue/green under ALB; feature flags; rollback
- Capacity planning: HPA/VPA, requests/limits, load test strategy

ATS Keywords

- SRE, SLOs, SLIs, Error Budgets, Prometheus, Grafana, On-call, Incident Response, Runbooks, Blue/Green, Canary, HPA, Kubernetes, EKS, AWS

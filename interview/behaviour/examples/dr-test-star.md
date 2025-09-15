# Example: Disaster Recovery Test (AU Regions) — STAR

Situation

- Agency needed DR validation between `ap-southeast-4` (Melbourne) and `ap-southeast-2` (Sydney) for a critical service.

Task

- Prove RTO 60 minutes/RPO 15 minutes; document runbooks and evidence.

Action

- Automated backup/restore and DNS failover scripts; validated infra with Terraform plan checks; load tested in DR.
- Coordinated change approvals; captured CloudWatch and CloudTrail evidence; documented runbook and post‑test ADR.

Result

- Achieved RTO 42 minutes/RPO 10 minutes; audit sign‑off; recurring quarterly DR exercise established.

Keywords

- DR, RTO/RPO, Melbourne/Sydney, Terraform, DNS failover, Runbooks

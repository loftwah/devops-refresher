# Example: Terraform Governance (OPA/Policies) — SOAR

Situation

- Multiple teams deploying to EKS with varying standards; audit raised concerns about public exposure and drift.

Obstacle

- Teams feared velocity impact from strict policies.

Action

- Introduced OPA/Gatekeeper policies for ALB ingress, IRSA, and SG rules; created exception process.
- Provided Terraform module examples and CI checks; ran brown‑bag sessions.
- Captured decisions in ADRs; gradually increased policy enforcement from warn→deny.

Result

- 0 public S3/0.0.0.0/0 regressions; faster reviews; audit concern closed; teams reported clearer paved paths.

Keywords

- OPA, Gatekeeper, Terraform, EKS, Policy‑as‑code, ADR, Audit

# Impact Phrasing Without Sharing Metrics

When you can’t share internal figures, use specific, verifiable outcomes without numbers.

What to emphasise

- Reliability: “no customer-reported downtime”, “self-healing design”, “graceful degradation”
- Speed: “minutes, not hours”, “same-day deployments”, “release on demand”
- Safety: “rollback in one step”, “guardrails prevent risky configs”, “audit-ready changes”
- Scale: “handled peak seasonal load”, “sustained heavy traffic without incident”
- Risk/Compliance: “closed audit finding”, “least-privilege baseline enforced”, “evidence captured automatically”

Phrasing patterns

- “Reduced manual steps by introducing … resulting in fewer errors and faster recovery.”
- “Enabled safe releases during change freezes via canary + auto-rollback.”
- “Codified IAM/SG baselines; changes are now reviewable and traceable.”
- “Implemented SLOs and alert routing; incidents are resolved faster with clear runbooks.”
- “Templated CI/CD; teams deploy consistently with built-in checks and policy.”

Portfolio‑anchored proof (no numbers needed)

- Link to code/templates (e.g., `aws-labs/17-eks-cluster/`, `aws-labs/18-eks-alb-externaldns/`, `aws-labs/20-cicd-eks-pipeline/`).
- Link to decisions/runbooks (`docs/decisions/*.md`, `docs/runbooks/*`).
- Link to public projects and posts (see featured links guide).

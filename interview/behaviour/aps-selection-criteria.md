# APS Selection Criteria (SAO/STAR for Government)

Context

- APS applications often require a short pitch or selection criteria responses. Use SAO (Situation, Action, Outcome) or STAR compressed.

Approach

1. Identify the capability (e.g., “Achieves results”, “Supports productive working relationships”).
2. Pick one strong story; ensure evidence and measurable outcome.
3. Write 250–400 words in SAO; explicitly reference controls/evidence where relevant.

APS Capability → Example prompts

- Communicates with influence: “Persuaded security and delivery to adopt OPA policies without slowing releases.”
- Supports strategic direction: “Aligned platform roadmap (EKS/Terraform) with agency cloud strategy and data residency.”
- Achieves results: “Cut incident volume while meeting audit requirements during change freeze.”
- Supports productive working relationships: “Led cross‑team runbook standardisation pre‑DR test.”
- Displays personal drive and integrity: “Raised a risk about secrets handling; implemented safer pattern with evidence.”

Example SAO (Achieves results)

- S: “Facing recurring prod incidents and an open audit finding on change traceability before a major public deadline.”
- A: “Introduced SLOs/SLIs with Prometheus/Grafana; created runbooks; codified IAM/SG baselines and CloudTrail evidence in Terraform; set deploy gates (canary/rollback).”
- O: “Sev‑1s reduced 40%; MTTR halved; audit finding closed with automated evidence; stakeholders reported improved confidence.”

Example SAO (Communicates with influence)

- S: “Security requested blanket freezes; delivery needed releases for critical fixes.”
- A: “Facilitated risk‑based policy with OPA + deploy gates; documented ADR; ran pilot with 5% canary.”
- O: “Approved releases within freeze policy; zero customer impact; policy adopted across teams.”

Do/Don’t (Government)

- Do: emphasise controls, auditability, privacy, and documented decisions
- Don’t: reveal sensitive architecture details; instead reference artefacts generically

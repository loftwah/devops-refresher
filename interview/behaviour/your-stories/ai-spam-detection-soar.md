# GPT‑4 Spam Detection — SOAR (Dean)

Situation

- Customer communications suffered from spam/noise; manual triage slowed support.

Obstacle

- Accuracy concerns and risk of false positives; need for explainability.

Action

- Prototyped GPT‑4 classifier with guardrails; added confidence thresholds and human‑in‑the‑loop review; instrumented metrics and feedback loop.
- Deployed behind feature flag via CI/CD; documented runbook and rollback.

Result

- Reduced manual triage time; positive feedback from CTO; plan to iterate on thresholds and model prompts.

Keywords

- GPT‑4, CI/CD, Feature Flags, Observability, Runbooks, Human‑in‑the‑loop

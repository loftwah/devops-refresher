# Example: Major Incident (SRE) — STAR

Situation

- Black Friday traffic caused API p95 latency to breach SLO. Change freeze active; AU users primarily in `ap-southeast-4`.

Task

- As on‑call SRE, restore SLO and prevent recurrence without violating freeze policy.

Action

- Enabled 5% canary behind ALB; tuned HPA targets; added Redis cache TTL for hot paths.
- Set abort/rollback gates; coordinated with security and product in incident channel.
- Captured evidence: runbook entries, Grafana snapshots, CloudTrail change record; authored ADR for cache policy.

Result

- p95 down 35% within 28 minutes; zero user‑visible errors; no policy breach; follow‑up items completed within a week; SLO burn returned to budget.

Learnings

- Add load test profiles ahead of events; pre‑approve safe toggles during freezes.

Keywords

- SRE, SLOs, Prometheus/Grafana, ALB, Canary, HPA, ADR, Runbook, Melbourne

# STAR Deep Dive (with APS/Government Focus)

Why STAR matters

- Clear structure under pressure; works for APS panels and private companies.
- Lets you show judgement, risk management, and measurable outcomes.

When to use STAR vs SOAR vs CAR vs SAO

- STAR: general behavioural answers (2–3 mins)
- SOAR: highlight obstacles in regulated/risky work
- CAR: tight answers when timeboxed (<90s)
- SAO: APS selection criteria/pitches (written), concise evidence focus

Timing patterns

- 2–3 min verbal: 20% Situation, 10% Task, 50% Action, 20% Result/Reflection
- 5 min verbal: add trade‑offs, stakeholder mgmt, and metrics detail
- Written (APS): 250–400 words per criterion (SAO/STAR‑lite)

Metrics you can use (DevOps/SRE)

- Reliability: error rate, SLO burn, incidents/Sev‑1s, MTTR/MTBF
- Delivery: lead time, deployment frequency, change failure rate, rollback time
- Cost/Risk: infra spend, storage/egress, audit findings closed, exception volume

Government/APS specifics

- Evidence: reference artefacts (runbooks, ADRs, change records) without sensitive details
- Privacy: describe data classes/process, not actual data
- Risk language: likelihood/impact, control effectiveness, residual risk
- Values framing: Impartial (data‑driven), Committed to Service (user outcomes), Accountable (traceability), Respectful (collaboration), Ethical (security/compliance)

Phrase bank

- Situation: “In a change freeze before EOFY with APRA audit open…”
- Task: “I owned reducing SLO burn without breaching the freeze policy.”
- Action: “I proposed a canary limited to 5% with explicit rollback gates…”
- Result: “Cut Sev‑1s by 40% and halved MTTR; audit finding closed.”
- Reflection: “Next time I’d add automated evidence capture earlier (CloudTrail).”

Common pitfalls (and fixes)

- Rambling context → Keep Situation ≤30s; jump to stakes and ownership
- Tool drop (no impact) → Always quantify Result and link to user/mission
- “We did” with no “I did” → Clarify your decision boundary and actions
- No trade‑offs → Name 1–2 alternatives and why you chose your path

Layering technique (panel follow‑ups)

- Start concise → expand on metrics → expand on risk/controls → expand on stakeholder mgmt → offer artefacts (runbook/ADR names)

Mini example (STAR, 2 min)

- S: “Prod API breached latency SLO during promo; change freeze in effect.”
- T: “As on‑call SRE, reduce burn rate without violating freeze.”
- A: “Enabled canary at 5% behind ALB; tuned HPA; added cache TTL; set abort/rollback gates; notified comms channel; documented in runbook.”
- R: “p95 latency down 35%; zero user‑visible errors; no freeze breach; closed incident in 28m; follow‑up ADR on cache strategy.”

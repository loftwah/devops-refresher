# System Design (DevOps/SRE Focus)

Emphasis: reliability, operability, change safety, and platform ergonomics.

Core Topics

- Scaling: load balancers, autoscaling, queues, backpressure
- Reliability: SLIs/SLOs, error budgets, graceful degradation, retries
- Delivery: CI/CD strategies (blue/green, canary, feature flags)
- Data: SQL vs NoSQL, read/write patterns, caching (CDN/Redis), consistency
- Infra: multi-account AWS, VPC design, boundaries, identity/IAM
- Observability: metrics, logs, traces, alerting, runbooks, SLO dashboards
- Security: secrets, least privilege, image/build security, supply chain

Australia Context

- Primary region often `ap-southeast-2`; consider DR (e.g., `ap-southeast-4`)
- Data residency/compliance (esp. gov/banks)
- Latency to US/EU; multi-region read caches/CDN

Process

1. Clarify functional/non-functional requirements (scale, latency, RTO/RPO)
2. Draw the high-level: clients → edge → services → data → observability
3. Dive into 2–3 critical components; discuss trade-offs
4. Deployment strategy and ops: how you ship and operate safely
5. Risks, failure modes, testing, cost considerations

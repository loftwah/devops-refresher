# Mission‑Critical Streaming in 72 Hours — STAR (Dean)

Situation

- CEO requested a high‑priority streaming system for customer support with near‑immediate turnaround. Existing stack lacked real‑time capability and redundancy.

Task

- Deliver a secure, scalable streaming service within 72 hours, with redundancy and monitoring, aligning to company security standards.

Action

- Designed a redundant architecture spanning EC2 and ECS; containerised services and built IaC where practical to accelerate provisioning.
- Implemented GitHub Actions pipelines (Ruby + AWS SDK) for rapid deploys; added observability (CloudWatch + dashboards) and alerting.
- Coordinated with security for minimal viable controls (IAM, SGs) and documented rollback/runbooks.

Result

- Launched within 72 hours; achieved availability and performance targets; executive stakeholder satisfied; foundation reused for later services.

Learnings

- Pre‑baked templates and paved paths reduce time‑to‑value; add canary hooks by default.

Keywords

- ECS, EC2, CI/CD, GitHub Actions, IAM, Security Groups, Runbooks, Observability

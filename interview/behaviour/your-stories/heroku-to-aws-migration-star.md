# Migrated 4 Legacy Apps (Heroku → AWS) — STAR (Dean)

Situation

- Four legacy Classtag applications ran on Heroku with platform risk and limited control over networking, secrets, and runtime.

Task

- Migrate to AWS with minimal downtime, modernise the deployment stack, and align with enterprise security and reliability standards.

Action

- Containerised apps; designed ECS + RDS architecture; implemented IaC (Terraform modules) and secrets via Parameter Store.
- Built GitHub Actions pipelines (Ruby + AWS SDK) with environment gates and rollback; added monitoring/alerts (CloudWatch, Grafana).
- Coordinated cutover windows and rehearsed runbooks; documented decisions for TLS, IAM, and change safety.

Result

- Successful migration with reduced platform risk; improved deployment reliability and speed; clearer audit trail and operations.

Learnings

- Invest in repeatable modules/templates; add smoke tests and runbooks early to de‑risk cutovers.

Keywords

- AWS, ECS/Fargate, RDS, Terraform, CI/CD, Secrets, Runbooks, TLS, IAM

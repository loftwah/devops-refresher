# Scenario: Cloud Engineer @ Telstra (Hypothetical)

Role Snapshot

- Build secure AWS landing zones and shared services for regulated workloads; strong emphasis on IAM, network boundaries, and audit.

Behavioural (choose 2)

- Balancing delivery speed with compliance in a regulated environment
- Handling a production change freeze and exceptions

Coding

- Write a tool to scan Terraform code for prohibited resources/configs (e.g., public S3, 0.0.0.0/0 SG) and produce a report.

System Design

- Design a multi-account AWS landing zone with centralised identity, networking (Transit Gateway), logging/monitoring, golden AMIs, and CI/CD with policy.
- Include DR between `ap-southeast-2` and `ap-southeast-4`.

Evaluation Hooks

- Guardrails, auditability, secrets, blast-radius, cost controls

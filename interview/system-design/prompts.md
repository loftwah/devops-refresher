# System Design Prompts (DevOps/SRE)

1. Design a multi-tenant CI/CD platform for microservices

- Requirements: 500 services, 200 daily deploys, approvals, audit, secrets, rollbacks
- Discuss runners, scaling, caching, artifact store, policy (OPA), cost

2. Design a highly available API in `ap-southeast-2`

- SLO: 99.9%, p95 < 200ms AU; DR to `ap-southeast-4`
- Cover load balancing, autoscaling, DB HA, cache, failover, health checks

3. Design an observability stack

- Metrics (Prometheus), logs (Loki/ELK), traces (Tempo/Jaeger), alerting, SLOs
- Multi-cluster scraping, retention tiers, cost controls

4. Design secrets management

- AWS KMS + Secrets Manager/HashiCorp Vault, rotation, perf, break-glass, auditing

5. Design blue/green + canary deployment strategy

- For `demo-node-app/` style service on EKS with ALB; include feature flags

6. Design a secure multi-account AWS landing zone

- Networking, identity, CI/CD, guardrails, golden images, incident response

7. Edge caching for AU users with global expansion

- CDN, cache invalidation, regional read replicas, data residency constraints

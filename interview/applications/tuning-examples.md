# Tuning Examples (Role, Industry, Company)

Use these “what/where/why/when/how” patterns to customise resumes, LinkedIn, and cover letters.

## Role Examples

Platform Engineer

- What: multi‑tenant EKS, Terraform modules, OPA, IRSA, Helm paths.
- Where: `aws-labs/17-eks-cluster/`, `aws-labs/18-eks-alb-externaldns/`, `aws-labs/kubernetes/helm/demo-app/`.
- Why: platform ownership and paved paths.
- When: hiring for scale or many teams; “Platform” or “Developer Productivity” labels.
- How (resume bullet): “Built EKS platform via Terraform modules; added IRSA/OPA and ALB ingress with ExternalDNS, enabling safe paved paths for 50+ services.”

SRE

- What: SLOs/SLIs, alerts, incident response, rollouts, MTTR.
- Where: `aws-labs/16-observability/`, `docs/runbooks/*`, `docs/decisions/ADR-001-alb-tls-termination.md`.
- Why: outcome focus on reliability.
- When: on‑call ownership; “SRE”/“Production Engineering” roles.
- How: “Defined SLOs and alert strategy; reduced Sev‑1s 40% using Prometheus/Grafana and runbooks; enabled safe canaries on ALB/EKS.”

Cloud Engineer

- What: VPC/IAM, endpoints, ALB, RDS, Terraform state, security groups.
- Where: `aws-labs/00-backend-terraform-state/`, `01-vpc/`, `02-vpc-endpoints/`, `06-iam/`, `12-alb/`, `09-rds/`.
- Why: secure, auditable foundations; regulated markets.
- When: gov/banks/enterprises.
- How: “Codified VPC + endpoints + IAM baselines with Terraform; enforced SG patterns; documented TLS termination on ALB.”

DevOps Engineer

- What: CI/CD, Docker, EKS/ECS deploys, validation/policy, developer enablement.
- Where: `demo-node-app/Dockerfile`, `demo-node-app/buildspec.yml`, `aws-labs/20-cicd-eks-pipeline/`, `docs/validation-strategy.md`.
- Why: speed with guardrails.
- When: scale‑ups, product teams.
- How: “Reduced lead time 70% by templating CI; added image scans and deploy gates; automated EKS deploys with Helm.”

## Industry Examples

Bank/FSI

- What: risk, audit, DR, change mgmt.
- Where: `docs/cloudtrail.md`, `aws-labs/00-backend-terraform-state/`, `07-security-groups/`.
- Why: compliance.
- When: mention change freezes/exception paths, DR drills.
- How (cover bullet): “Automated evidence capture (CloudTrail) and codified SG/IAM baselines, reducing audit findings by 30%.”

Government

- What: data residency, private networking, identity.
- Where: `docs/vpc.md`, `aws-labs/02-vpc-endpoints/`, `12-alb/`.
- Why: sovereignty/regulatory fit.
- When: note clearance eligibility if applicable.
- How: “Designed private networking with endpoints; documented controls and DR between `ap-southeast-2`/`-4`.”

Scale‑up/SaaS

- What: velocity, preview envs, paved paths, cost.
- Where: `aws-labs/20-cicd-eks-pipeline/`, Helm, ADRs.
- Why: speed safely.
- When: fast‑moving teams.
- How: “Introduced reusable pipelines and Helm templates; p95 pipeline <15m and safer rollbacks.”

Telco/Enterprise

- What: HA, change mgmt, incident response, network boundaries.
- Where: `aws-labs/12-alb/`, `16-observability/`, `docs/terraform-modules.md`.
- Why: scale + stability.
- When: large estates, multiple teams.
- How: “Blue/green on ALB/EKS with runbooks; change failure rate 25%→10%.”

## Company‑Style Snippets

Atlassian (values + DX)

- Headline: “Platform Engineer | AWS EKS, Terraform, OPA | Paved Paths”
- About: “I enable teams to ship safely with canary/feature flags on EKS.”
- Proof: `aws-labs/17-eks-cluster/`, `aws-labs/20-cicd-eks-pipeline/`.

Canva (simplicity + speed)

- Headline: “SRE | SLOs, Observability | Fast + Reliable at Scale”
- About: “Improved reliability and p95 latency with SLOs and autoscaling.”
- Proof: `aws-labs/16-observability/`, ALB + Helm rollouts.

Telstra (reliability + audit)

- Headline: “Cloud Engineer | AWS VPC/IAM/ALB | Secure & Auditable”
- About: “Hardened AWS landing patterns with documented TLS/SG strategy.”
- Proof: `docs/security-groups.md`, `aws-labs/12-alb/`.

## LinkedIn About Variants

- Platform: “Built EKS with Terraform modules, IRSA, OPA; enabled paved paths. See `aws-labs/17-eks-cluster/`.”
- SRE: “SLOs/SLIs, Prometheus/Grafana, incident response; cut Sev‑1s 40%. See `aws-labs/16-observability/`.”
- Cloud: “AWS VPC/IAM/ALB, RDS; codified baselines with Terraform. See `aws-labs/01-vpc/`.”
- DevOps: “CI/CD, Docker, EKS; reusable pipelines + gates. See `aws-labs/20-cicd-eks-pipeline/`.”

## Headline Recipe

- Format: <Role> | <Core Stack> | <Outcome>
- Example: “DevOps Engineer | CI/CD, Docker, EKS | Faster, Safer Releases”

## Outreach Templates

Hiring Manager/Engineer

- “Hi <Name> — I’m targeting <role>. I’ve built <X> (<repo link>). Could we do 15 min to learn about <team/stack>? Happy to share specifics relevant to <JD keyword>.”

Recruiter

- “Hi <Name>, I focus on <skills>. Recent work: EKS via Terraform and CI/CD to EKS. Open to <perm/contract> in <city/remote>?”

Follow‑up (5–7 days)

- “Quick update — added <artifact/diagram> showing <relevant JD item>. Still keen; would love a quick chat.”

## JD Keyword Map (Mini Example)

- Inputs: 10 JDs (Seek + LinkedIn) for SRE/Platform in AU.
- Categories: Cloud(AWS/EKS), IaC(Terraform), CI/CD(GitHub Actions/CodeBuild), Observability(Prom/Grafana), Security(IAM/SG), Delivery(blue/green/canary), Ops(SLO/SLI/runbooks).
- Output: top recurring terms and verbs to mirror in Summary and top bullets.

## Before/After Examples (More)

- “Maintained Kubernetes clusters” → “Provisioned EKS with Terraform; introduced IRSA and OPA Gatekeeper; cut manual changes by 90%.”
- “Set up monitoring” → “Implemented Prometheus/Grafana with SLOs and alert routing; reduced alert noise 60%.”
- “Built pipelines” → “Templated CI for Docker builds + image scan + Helm deploy; p95 pipeline time <15m.”

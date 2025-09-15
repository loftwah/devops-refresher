# How To Tailor Applications (Step‑by‑Step Walkthroughs)

Goal: show exactly how to go from a JD to a tailored resume, LinkedIn tweaks, and a cover letter — using artifacts from this repo.

## Framework (What/Where/Why/When/How)

- What: Identify the 6–8 must‑have skills/outcomes in the JD.
- Where: Map each to concrete evidence in your repo (paths, ADRs, runbooks).
- Why: State the impact those artifacts enable (faster deploys, safer changes, better reliability).
- When: Note operational context (on‑call, DR windows, release cadence).
- How: Rewrite your Summary and top role bullets using JD phrasing and your evidence.

Checklist

- Collect 10 JDs → keyword map
- Pick one JD → highlight must‑haves → map to repo
- Rewrite Summary, 3–5 bullets, and Skills order
- Update LinkedIn headline/About to match the JD language
- Draft a 3–4 bullet cover letter

## Walkthrough 1: SRE @ Bank (Melbourne)

JD (hypothetical core asks)

- SLOs/SLIs; incident response; audit-ready changes; AWS; Terraform; DR in AU.

Map JD → Repo

- SLOs/SLIs/alerts → `aws-labs/16-observability/`, `docs/runbooks/*`
- Auditability → `docs/cloudtrail.md`, `docs/security-groups.md`, `docs/iam.md`, `aws-labs/06-iam`, `07-security-groups`
- AWS+Terraform → `aws-labs/*` modules, `00-backend-terraform-state/`
- DR (ap-southeast-4 <-> -2) → mention in `interview/applications/au-melbourne-market-guide.md`

Rewrite

- Summary: “SRE focused on reliability and auditability. Implemented Prometheus/Grafana SLOs and codified IAM/SG and CloudTrail evidence with Terraform. Melbourne‑based; design for `ap-southeast-4` with DR to `-2`.”
- Bullets:
  - “Cut Sev‑1s 40% by implementing SLOs/alerts and runbooks (`aws-labs/16-observability`, `docs/runbooks/*`).”
  - “Codified IAM/SG baselines and CloudTrail evidence in Terraform (`docs/iam.md`, `docs/security-groups.md`, `docs/cloudtrail.md`).”
  - “Safe canary/blue‑green on EKS with ALB/TLS (`aws-labs/18-eks-alb-externaldns`).”
- LinkedIn headline: “SRE | SLOs, Prometheus, Incident Response | 99.9%+ | Melbourne”
- Cover letter: use `cover-letters/commonwealth-bank-sre.md` and swap details.

## Walkthrough 2: Platform Engineer @ Scale‑up

JD (hypothetical asks)

- Paved paths on EKS, Terraform modules, IRSA/OPA, CI/CD to EKS, observability, cost awareness.

Map JD → Repo

- EKS modules → `aws-labs/17-eks-cluster/`
- OPA/policies → `aws-labs/kubernetes/policies/`
- CI/CD to EKS → `aws-labs/20-cicd-eks-pipeline/`, `demo-node-app/buildspec.yml`
- Observability → `aws-labs/16-observability/`

Rewrite

- Summary: “Platform engineer building paved paths on EKS with Terraform, IRSA/OPA, and CI/CD to EKS.”
- Bullets:
  - “Provisioned EKS via Terraform; added IRSA/OPA; safe multi‑tenant ingress with ALB/ExternalDNS.”
  - “Reusable pipelines deploying Helm charts; p95 pipeline <15m; rollback under 5m.”
  - “SLO dashboards and alert routing; clear runbooks to cut MTTR.”
- LinkedIn headline: “Platform Engineer | AWS, EKS, Terraform, OPA | Paved Paths”
- Cover letter: base on `cover-letters/atlassian-platform-engineer.md`.

## Walkthrough 3: Cloud Engineer @ Telco

JD (hypothetical asks)

- VPC with endpoints, IAM least privilege, ALB/TLS, runbooks, change safety.

Map JD → Repo

- VPC + Endpoints → `aws-labs/01-vpc/`, `02-vpc-endpoints/`
- IAM/SGs → `aws-labs/06-iam/`, `07-security-groups/`, `docs/iam.md`, `docs/security-groups.md`
- ALB/TLS → `aws-labs/12-alb/`, `docs/decisions/ADR-001-alb-tls-termination.md`
- Runbooks → `docs/runbooks/*`

Rewrite

- Summary: “Cloud engineer building secure AWS foundations with Terraform.”
- Bullets:
  - “Codified VPC+endpoints; private networking by default.”
  - “Documented ALB/TLS strategy; blue/green with rollback runbooks.”
  - “IAM least privilege and SG baselines; CloudTrail for audit.”
- LinkedIn headline: “Cloud Engineer | AWS VPC/IAM/ALB | Melbourne”
- Cover letter: base on `cover-letters/telstra-cloud-engineer.md`.

# LinkedIn + Seek Playbook (Australia)

Goal: increase inbound recruiter messages and interview invites.

## What to Optimise (Order of Impact)

- Headline: searchable keywords + outcome. Example: “Platform Engineer | AWS EKS, Terraform, CI/CD | Ship Faster, Safer”
- About: 3–5 lines with outcomes, scale, stack, and target impact.
- Experience: impact bullets with metrics, mirroring JD keywords.
- Featured: add links to repo artifacts: `demo-node-app/`, `aws-labs/17-eks-cluster/`, ADRs.
- Skills: pin 3–5 most relevant to target JD; ensure endorsements.

## Where to Find Keywords

- Job descriptions (Seek + LinkedIn) — collect 10 and build a map.
- Company career pages and engineering blogs — language they use internally.
- People in-role — review their LinkedIn skills and About sections.
- This repo — mirror concrete artifacts you actually have.

## Why Tuning Works

- ATS/LinkedIn search matches titles, headlines, About, and skills to queries.
- Recruiters skim 10–20 seconds; matching phrasing reduces cognitive load.
- Company-specific language (values, stack) signals fit and preparation.

## LinkedIn

Profile

- Headline: role | strongest stack | outcome. Example variants:
  - Platform: “Platform Engineer | AWS, EKS, Terraform, Helm | Dev Velocity + Reliability”
  - SRE: “SRE | SLOs, Prometheus/Grafana, Incident Response | 99.9%+ Availability”
  - Cloud: “Cloud Engineer | AWS VPC/IAM/ALB, Terraform | Secure Foundations”
  - DevOps: “DevOps Engineer | CI/CD, Docker, EKS/ECS | Faster, Safer Releases”
- About: keep outcome-first. Example:
  - “I build reliable platforms on AWS. In this repo: EKS via Terraform (`aws-labs/17-eks-cluster/`), ALB+ExternalDNS (`aws-labs/18-eks-alb-externaldns/`), CI/CD to EKS (`aws-labs/20-cicd-eks-pipeline/`), observability (`aws-labs/16-observability/`). Looking to help <industry> ship faster and safer in AU.”
- Experience: rewrite bullets using JD verbs and your artifacts; quantify impact.
- Skills: ensure target JD keywords appear in top 10 (AWS, Kubernetes, Terraform, CI/CD, SRE).
- Featured: link to repo folders and short READMEs describing outcomes.

Search & Alerts

- Save searches: title (“DevOps”, “Platform Engineer”, “SRE”), location (Sydney/Melbourne/Brisbane/Remote AU), experience level, on‑site vs remote.
- Set weekly alerts; follow target companies (Atlassian, Canva, Telstra, NAB, Xero, AWS, CSIRO).

Outreach

- Hiring Manager/Engineer: “Hi <Name> — I’m targeting <role>. I’ve built <relevant> (e.g., `aws-labs/20-cicd-eks-pipeline/`). 15 min to learn about <team/stack>? Happy to share specifics. Cheers, <you>.”
- Recruiter: “Hi <Name>, I focus on <skills>. Recent work: EKS via Terraform and CI/CD to EKS (links). Any opportunities for <role> in <city/remote>?”
- Alumni/Community: “Hi <Name>, fellow <uni/community>. I’m exploring <role> at <company>. Could I ask 3 quick questions about the interview expectations?”

When to Outreach

- Right after saving a JD and tailoring your resume; within 24 hours of posting.
- Follow up 5–7 days later with a brief update (e.g., new artifact or insight).

## Seek

Search

- Filters: salary, contract vs perm, remote/hybrid, posted in last 7 days, exact title keywords.
- Track 10–20 roles/week; export JDs to your keyword map.

Applications

- Tailor a 1‑page resume per JD; short cover letter (3–4 bullets).
- Mirror must‑have keywords in Summary and top role bullets.
- Upload ATS‑friendly PDF; no tables/columns/images.

## AU Recruiters

- Agencies: Hays, Michael Page, Robert Half, Paxus, Greythorn, Peoplebank.
- In‑house: talent partners at Atlassian, Canva, Telstra, banks, scale‑ups.
- Use them for market intel, salary bands, interview process insights, referrals.

## Tuning by Role (What/Where/Why/How)

Platform Engineer

- What to emphasise: multi‑tenant EKS, paved paths, Terraform modules, OPA, IRSA.
- Where in repo: `aws-labs/17-eks-cluster/`, `aws-labs/18-eks-alb-externaldns/`, `aws-labs/kubernetes/helm/demo-app/`, `docs/decisions/ADR-007-cicd-eks-pipeline.md`.
- Why: signals ownership of platform surfaces and developer experience.
- How (headline/about): “Platform Engineer | AWS EKS, Terraform, OPA | Enable 500+ services.”

SRE

- What: SLOs/SLIs, alerts, incident response, deploy safety, MTTR.
- Where: `aws-labs/16-observability/`, `docs/runbooks/*`, `docs/decisions/ADR-001-alb-tls-termination.md`.
- Why: reliability outcomes over tools.
- How: “SRE | SLOs, Prometheus, Incident Response | 99.9%+ availability.”

Cloud Engineer

- What: VPC/IAM, endpoints, ALB, RDS, security posture, IaC.
- Where: `aws-labs/01-vpc/`, `02-vpc-endpoints/`, `06-iam/`, `12-alb/`, `09-rds/`.
- Why: secure foundations, regulated environments.
- How: “Cloud Engineer | AWS VPC/IAM/ALB, Terraform | Secure foundations.”

DevOps Engineer

- What: CI/CD, Docker, ECS/EKS deploys, policy/validation, developer enablement.
- Where: `demo-node-app/Dockerfile`, `demo-node-app/buildspec.yml`, `aws-labs/20-cicd-eks-pipeline/`, `docs/validation-strategy.md`.
- Why: delivery speed with safety.
- How: “DevOps | CI/CD, Docker, EKS | Faster, safer releases.”

## Tuning by Industry (What/Where/Why/When/How)

Banks/Financial Services

- What: risk, compliance, auditability, change freezes, DR, least privilege.
- Where: `docs/cloudtrail.md`, `docs/security-groups.md`, `aws-labs/00-backend-terraform-state/`, `07-security-groups/`.
- Why: regulated environment expectations.
- When: note on‑call maturity, freezes, and exception processes.
- How (bullet): “Codified least‑privilege IAM and SG baselines in Terraform; enabled audit trails (CloudTrail) and automated evidence collection — reduced change exceptions by 30%.”

Government/Defence

- What: data residency (`ap-southeast-2`/`-4`), network segmentation, identity, potential clearance eligibility.
- Where: `docs/vpc.md`, `aws-labs/02-vpc-endpoints/`, `12-alb/`.
- Why: compliance and sovereignty.
- When: mention clearance eligibility up front if applicable.
- How: “Designed private networking with VPC endpoints and ALB/TLS termination; documented controls for audit.”

Scale‑ups/SaaS

- What: developer velocity, paved paths, preview envs, cost awareness.
- Where: `aws-labs/20-cicd-eks-pipeline/`, Helm charts, ADRs.
- Why: speed with guardrails.
- When: highlight time‑to‑value improvements.
- How: “Reduced lead time 70% by templating CI/CD and Helm deploys; added OPA checks to keep prod safe.”

Telco/Enterprise

- What: network boundaries, high availability, change mgmt, incident response at scale.
- Where: `docs/terraform-modules.md`, `aws-labs/12-alb/`, `16-observability/`.
- Why: large scale ops pragmatism.
- How: “Implemented ALB‑backed blue/green on EKS with runbooks; cut change failure rate from 25%→10%.”

## Company‑Style Examples (Atlassian/Canva/Telstra)

Atlassian

- Why: values (open company, no bullshit), developer experience.
- How (About line): “Built paved paths on EKS with Terraform and OPA; enabled teams to ship safely with canary/feature flags.”

Canva

- Why: simplicity, speed, user impact.
- How: “Improved p95 latency and error rates via SLOs/alerts; built autoscaling and CDN cache strategies.”

Telstra

- Why: reliability, risk management, clear audit.
- How: “Hardened AWS landing patterns (VPC, IAM, ALB/TLS); produced audit‑ready runbooks and ADRs.”

## Before/After Bullet Examples (Using This Repo)

- Before: “Worked on Kubernetes and Terraform.”
- After (Platform): “Provisioned EKS with Terraform modules (`aws-labs/17-eks-cluster/`); added IRSA and OPA policies, enabling safe multi‑tenant workloads.”
- Before: “Set up CI/CD.”
- After (DevOps): “Built CI/CD to EKS (`aws-labs/20-cicd-eks-pipeline/`, `demo-node-app/buildspec.yml`); reduced lead time 70% with reusable workflows.”
- Before: “Monitored services.”
- After (SRE): “Implemented Prometheus/Grafana (`aws-labs/16-observability/`); defined SLIs/SLOs and cut Sev‑1s by 40% with actionable alerts and runbooks.”

## When to Apply and Follow Up

- Apply within 24–48 hours of posting; tailor resume and cover letter.
- Follow up in 5–7 days if no response; add one new proof point (repo/diagram).
- If rejected, request brief feedback; ask to be considered for future roles.

## Weekly Cadence

- Mon: 5 tailored applications (Seek + LinkedIn)
- Tue–Wed: 3 informational chats (alumni, meetups, Slack)
- Thu: portfolio updates (readme, diagrams, small blog)
- Fri: review outcomes, iterate keyword map

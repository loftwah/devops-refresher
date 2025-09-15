# Company Research Playbook (LinkedIn‑first, AU/Melbourne)

Note: I can’t fetch live profiles here, but this guide shows how you can reliably find and study them.

## What To Collect

- Roles: titles, teams, level bands.
- Skills: pinned skills, About phrasing, tools they mention.
- Outcomes: metrics, scale, reliability numbers.
- Artifacts: blogs, talks, OSS links.

## Where To Look

- LinkedIn: employees filtered by title and location (Melbourne/VIC, Australia).
- Engineering blogs: Atlassian/Canva/AWS/Telstra; bank tech blogs; conference talks.
- Job posts: Seek + LinkedIn Jobs; save and export text to your keyword map.

## How To Search (LinkedIn/Google)

- LinkedIn People search: Title = “SRE” OR “Platform Engineer” OR “DevOps”, Location = Melbourne (or Australia).
- Boolean headline query on LinkedIn: title:(SRE OR "Site Reliability" OR Platform) AND (EKS OR Terraform OR SLO)
- Google: site:linkedin.com/in (SRE OR "Platform Engineer" OR DevOps) (EKS OR Terraform OR "Site Reliability") Melbourne
- Google: site:linkedin.com/jobs (Platform OR SRE) (EKS OR Terraform) Melbourne

## How To Study a Profile/JD

- Extract 6–8 repeated terms and verbs.
- Note phrasing patterns: “paved paths”, “guardrails”, “error budgets”, “auditability”.
- Map to your repo: match each term to a concrete artifact you can point to.
- Rewrite Summary and top bullets to mirror those phrases truthfully.

## Template: Research Notes

- Company: <name>
- Location: Melbourne (or AU‑wide)
- Role patterns: <titles/levels you see>
- Common skills: <top skills>
- Outcomes: <metrics language>
- Language to mirror: <phrases>
- Repo mapping: <paths you will cite>

## Example: Canva (hypothetical patterns)

- Skills: SLOs/SLIs, observability, autoscaling, incident response, simplicity.
- Language: “simple solutions”, “speed”, “data‑informed”.
- Repo mapping: `aws-labs/16-observability/`, ALB+Helm rollout, ADRs.

## Example: Telstra (hypothetical patterns)

- Skills: VPC/IAM/network, HA, change management, incident response.
- Language: “network boundaries”, “risk”, “audit”.
- Repo mapping: `aws-labs/01-vpc/`, `02-vpc-endpoints/`, `12-alb/`, runbooks.

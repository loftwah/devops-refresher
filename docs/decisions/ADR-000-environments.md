# ADR-000: Environments (Staging-Only Demo)

## Context

- This repo demonstrates an end-to-end AWS stack to run a demo app.
- To keep cost and complexity low, we use a single environment: staging.

## Decision

- Default environment is `staging` across naming, tags, and SSM/Secrets paths.
- Resource names, IAM roles, and SGs are prefixed with `staging-`.
- Parameter Store/Secrets Manager paths use `/devops-refresher/staging/app/*`.
- DNS uses subdomain `app.aws.deanlofts.xyz` for staging.

## Rationale

- A single, consistent environment simplifies the labs and avoids multi-env drift.
- All Terraform labs assume `staging` by default; overrides are possible but not required.

## How to Extend Later (Non-Goals for Demo)

- Add `env` as a variable to labs and derive names from it.
- Use separate AWS accounts or prefixes per env (e.g., `prod`).
- Use separate Route 53 records (e.g., `app.prod.example.com`).
- Duplicate Parameter Store/Secrets paths under `/devops-refresher/prod/app/*`.

## Checklist

- [x] Names and tags include `Environment = "staging"`.
- [x] SSM/Secrets paths include `/staging/`.
- [x] ECR image tags use `:staging` for the demo.
- [x] ALB DNS host is the staging host.

## References

- ADR-001 (ALB TLS termination)
- ADR-002 (Secrets and config)
- ADR-003 (Security groups)

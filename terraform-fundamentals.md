# Terraform Fundamentals (Quick but Thorough)

## State & Backends

- Purpose: Track real AWS resources vs desired config; enable plans/diffs.
- Remote backend: Use S3 for state + DynamoDB for state locking.
- Required: Versioned S3 bucket, server-side encryption, DynamoDB table with primary key `LockID`.
- Workspaces vs separate states: Prefer separate states (per env) for isolation; workspaces are OK for light separation.

Example backend:

```
terraform {
  required_version = ">= 1.5"
  backend "s3" {
    bucket         = "tf-state-<account>-<region>"
    key            = "staging/root.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
```

## Providers, Version Pinning, Cloud Credentials

- Pin providers (e.g., `hashicorp/aws ~> 5.0`).
- Source AWS creds from a named profile; never hardcode.
- Validate with `aws sts get-caller-identity` and `terraform providers`.

## Modules & Composition

- Prefer small, reusable modules per resource domain (vpc, alb, ecr, ecs, monitoring).
- Keep interfaces clean: `variables.tf` for inputs, `outputs.tf` for dependency boundaries.
- Version internal modules (tags or folders) to avoid accidental changes.

## Variables, Locals, Data Sources

- Variables: Only what must vary per env; default everything else.
- Locals: Centralize naming, tags, and common computed values.
- Data sources: Pull ARNs, images, AMIs, hosted zones, certs, etc., from AWS.

## Plans, Applies, and Safe Iteration

- Always: `fmt`, `validate`, `plan`, then apply.
- Small batches: One resource at a time → validate in AWS console/CLI.
- Tag everything: `Environment`, `Owner`, `CostCenter`, `App`.

## Drift, Imports, and Refactors

- Detect drift with `plan` and tooling (e.g., AWS Config or custom scripts).
- Import legacy resources: `terraform import <addr> <id>`; then model fields minimally; widen only as needed.
- Refactor with module outputs: Keep consumer modules stable; add `outputs` before moving resources.

## Secrets & Sensitive Data

- Prefer SSM Parameter Store (SecureString) or Secrets Manager + IAM policies.
- Mark Terraform variables `sensitive = true`; avoid writing secrets to state.

## Common Commands

- Init: `terraform init -upgrade`
- Validate: `terraform fmt -check && terraform validate`
- Plan: `terraform plan -var-file=staging.tfvars`
- Apply: `terraform apply -var-file=staging.tfvars`
- Show state: `terraform state list|show`
- Import: `terraform import` (then add config)

# Terraform Fundamentals (Quick but Thorough)

## State & Backends

- Purpose: Track real AWS resources vs desired config; enable plans/diffs.
- Remote backend: Use S3 for state with backend lockfiles (Terraform v1.13+). For older Terraform (<=1.9), use DynamoDB for state locking.
- Required: Versioned S3 bucket and server-side encryption; TLS-only bucket policy recommended.
- Workspaces vs separate states: Prefer separate states (per env) for isolation; workspaces are OK for light separation.

Example backend:

```
terraform {
  required_version = ">= 1.13.0"
  backend "s3" {
    bucket       = "tf-state-<account>-<region>"
    key          = "staging/root.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

Legacy (<= 1.9.x): replace `use_lockfile` with `dynamodb_table = "tf-locks"` and ensure a table exists with PK `LockID`.

## Providers, Version Pinning, Cloud Credentials

- Pin providers (e.g., `hashicorp/aws ~> 5.0`).
- Source AWS creds from a named profile; never hardcode.
- Validate with `aws sts get-caller-identity` and `terraform providers`.

## Provider Lockfile

- Purpose: `.terraform.lock.hcl` pins exact provider versions and checksums for reproducible, trusted installs across machines and CI.
- Lifecycle: Created/updated by `terraform init`; upgrade with `terraform init -upgrade` or explicitly with `terraform providers lock`.
- Multi-platform: Lock additional platforms for CI images or teammates, e.g. `terraform providers lock -platform=darwin_arm64 -platform=linux_amd64`.
- VCS: Commit the lockfile; do not hand-edit.

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

## State Files & Git

- Canonical state: With the S3 backend, the source of truth lives in the bucket (`key` path). Terraform handles locking (lockfile-based on v1.13+).
- Local files: `.terraform/` contains caches and a local working copy of state; `terraform.tfstate` may exist only if you ran without a backend before migrating.
- Git hygiene: Ignore all `*.tfstate*` and `.terraform/`; never commit state (it may contain secrets and ARNs).

## Common Commands

- Init: `terraform init -upgrade`
- Validate: `terraform fmt -check && terraform validate`
- Plan: `terraform plan -var-file=staging.tfvars`
- Apply: `terraform apply -var-file=staging.tfvars`
- Show state: `terraform state list|show`
- Import: `terraform import` (then add config)
- Lock providers for extra platforms: `terraform providers lock -platform=darwin_arm64 -platform=linux_amd64`

# Lab 00 – Terraform State (Consumer) Walkthrough

This directory configures Terraform to use the remote S3 backend that was bootstrapped in `00-backend-bootstrap`. It also sets provider defaults (region/profile) and a consistent tagging baseline for all resources managed in this repo.

## What Lives Here

- `backend.tf` – Defines the S3 backend:
  - Bucket: `tf-state-<account>-<region>` (from the bootstrap)
  - Key: `global/s3/terraform.tfstate` (state object for the backend resources)
  - Region: `us-east-1`
  - `use_lockfile = true`, `encrypt = true`, and `profile = devops-sandbox`
- `providers.tf` – Sets the AWS provider with:
  - `region` and `profile` variables
  - `default_tags` so resources across the repo automatically inherit tags
- `variables.tf` – `aws_region` and `aws_profile` defaults
- `versions.tf` – Pins Terraform and AWS provider versions

## Tagging Strategy

Provider `default_tags` ensures everything created via Terraform gets a consistent set of tags without repeating them on every resource:

- `Owner=Dean Lofts`
- `Environment=staging`
- `Project=devops-refresher`
- `App=devops-refresher`
- `ManagedBy=Terraform`

Downstream stacks can override or extend with resource-level `tags` when needed. The provider’s defaults are merged automatically.

## Why Two Labs for Backend?

- `00-backend-bootstrap`: Creates the S3 bucket (and security settings) used for remote state. This is applied once per account/region.
- `00-backend-terraform-state`: Points Terraform at that bucket as the backend and sets global provider defaults for this repo. It’s the “consumer” configuration to make other labs simpler.

## How to Use

This lab does not create additional AWS resources; it wires up the backend and provider defaults for consistency. To verify backend usage run:

```
terraform init
terraform providers
```

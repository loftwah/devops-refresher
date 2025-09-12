# Lab 00 – Backend Bootstrap Walkthrough

This directory bootstraps the S3 bucket that Terraform uses as a remote backend for all other labs. It’s a one-time, per-account/per-region setup that enforces security and consistency.

## What It Creates

- `aws_s3_bucket.tf_state` – State bucket named `tf-state-<account-id>-<region>` (built via `locals.account_id` and `var.aws_region`).
- `aws_s3_bucket_public_access_block` – Blocks all forms of public access.
- `aws_s3_bucket_versioning` – Enables versioning to protect from accidental state loss.
- `aws_s3_bucket_server_side_encryption_configuration` – AES256 encryption at rest.
- `aws_s3_bucket_policy` – Denies any non-TLS (`aws:SecureTransport=false`) requests.

## Provider and Tags

- `providers.tf` sets the AWS region/profile and applies provider `default_tags` so resources created here and downstream share a common tag baseline:
  - `Owner=Dean Lofts`, `Environment=staging`, `Project=devops-refresher`, `App=devops-refresher`, `ManagedBy=Terraform`.
- Other labs can override or extend tags at the resource level if needed.

## Why a Dedicated Bootstrap?

- Terraform cannot store its state in an S3 bucket that does not exist yet.
- This lab creates that bucket and secures it. Subsequent labs point at it using the `backend` block and a unique `key` per stack (e.g., `staging/network/terraform.tfstate`).

## How to Apply

```
cd aws-labs/00-backend-bootstrap
terraform init
terraform apply
```

Outputs include the final bucket name; other labs reference this in their `backend.tf`.

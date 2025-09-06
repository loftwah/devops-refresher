# Lab 00: Bootstrap Terraform Backend

## Objectives

- Create an S3 bucket for Terraform state and a DynamoDB table for state locking.
- Configure Terraform to use the remote backend.

## Tasks

1. Create S3 bucket `tf-state-<account>-<region>` with versioning and AES256 encryption.
2. Create DynamoDB table `tf-locks` with partition key `LockID` (string).
3. Add `backend` block to a new `providers.tf` or `main.tf` and run `terraform init`.

## Acceptance Criteria

- `terraform init` completes successfully; a `.terraform` directory references your S3 backend.
- State writes show new objects in S3 and a lock in DynamoDB on apply.

## Hints

- Enable S3 public access block and bucket policies to limit access to your AWS account.
- Use a dedicated IAM role or profile for IaC with least privilege.

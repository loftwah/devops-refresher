# Lab 00: Bootstrap Terraform Backend

## Objectives

- Create an S3 bucket for Terraform state.
- Configure Terraform to use the S3 backend with lockfile-based state locking (Terraform v1.13+; no DynamoDB).

## Structure

- `aws-labs/00-backend-bootstrap/`: one-time bootstrap that creates the S3 bucket (local state). Standard commands only.
- `aws-labs/00-backend-terraform-state/`: uses the created backend (S3 + lockfile locking). Standard commands only.

## What Gets Created (Bootstrap)

- **S3 Bucket:** `tf-state-<account>-<region>`
  - Versioning: Enabled
  - Encryption: SSE-S3 (AES256) default
  - Public Access Block: All four settings true
  - Bucket Policy: TLS-only (deny non-TLS access)

## Why Two Steps

- **Init needs a backend to exist:** Terraform can’t use a remote backend until the storage exists. The bootstrap stack creates the bucket; the state stack then initializes to S3 and stores state there.
- **Clean separation:** The state stack contains only the backend configuration, so `terraform apply` in that folder shows “No changes” (expected) because it manages no resources — it only uses the remote state.

## Multiple States (Beyond Bootstrap)

- You can keep many Terraform states in the same S3 bucket by using different backend `key` prefixes per stack/environment.
- Examples:
  - `bootstrap/global/terraform.tfstate` (this lab)
  - `staging/network/terraform.tfstate`, `staging/ecs/terraform.tfstate`
  - `prod/network/terraform.tfstate`, `prod/ecs/terraform.tfstate`
- Each stack sets its own `key` in `terraform { backend "s3" { ... } }` and will lock independently.
- For strict isolation or different KMS keys/policies, use separate buckets; otherwise a single bucket per account/region is standard.

## Tasks

1. Bootstrap (creates backend infra)
   - `cd aws-labs/00-backend-bootstrap`
   - `terraform init`
   - `terraform apply`
2. Configure and use remote backend
   - `cd aws-labs/00-backend-terraform-state`
   - `terraform init`
   - `terraform apply`

## Acceptance Criteria

- Bootstrap apply creates the S3 bucket with versioning, encryption, and TLS-only policy.
- In the state module, `terraform init` configures the S3 backend and uses lockfile-based locking without flags.
- Plans/applies read/write state from S3; apply shows “No changes” because the state module contains no resources.

## Notes

- Terraform cannot create its own remote backend before initialization. The one-time bootstrap keeps your main flow as plain `terraform init` and `terraform apply` without special flags.
- This lab targets Terraform v1.13.1. DynamoDB-based locking is deprecated in this version and replaced by backend lockfiles. If you must use DynamoDB locking, run with Terraform 1.9.x and switch the backend block accordingly.

## Verify Remotely Stored State

- **State file in S3:** Check the object under key `global/s3/terraform.tfstate` in the bucket output by bootstrap.
- **Terraform state commands:** `terraform state list` runs in `aws-labs/00-backend-terraform-state` and uses the S3 backend.
- **Lock messages:** You will see “Acquiring/Releasing state lock” messages; with lockfile-based locking, Terraform coordinates access without DynamoDB.

## Automated Validation

- Run `bash scripts/validate-backend.sh` from the repo root.
- Checks performed:
  - Reads the bucket name from `aws-labs/00-backend-bootstrap` outputs
  - Verifies the S3 bucket exists and the state object key `global/s3/terraform.tfstate` is present
  - Confirms backend config uses `use_lockfile = true`
  - Runs `terraform state list` in `aws-labs/00-backend-terraform-state` to confirm remote access

# Bootstrap Terraform Backend

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

## Don’t Skip the Backend

- Always initialize with the configured S3 backend. Skipping the backend (`terraform init -backend=false`) is not acceptable for day-to-day work in this repo because it can create local state, cause drift, and break cross-stack `terraform_remote_state` reads.
- CI, shared environments, and team workflows assume remote state, locking, and consistent outputs. Keep all `init/validate/plan/apply` wired to S3.

## Troubleshooting and Local-Only Checks

In rare, constrained environments (e.g., no network access on a dev machine) you may want to do a quick syntax check without contacting AWS. If—and only if—you need an isolated syntax/lint check:

- You may run `terraform validate` after a one-time `terraform init -backend=false` strictly for local parsing checks. Do not run `plan` or `apply` in this mode. Do not commit any generated local state.
- Before returning to normal work, clean any accidental local state: remove `.terraform/` and `terraform.tfstate*`, then run a full `terraform init -reconfigure` with the S3 backend.

Examples:

- Local-only parse check (air-gapped):
  - `terraform init -backend=false -input=false`
  - `terraform validate`
- Restore proper backend afterwards:
  - `rm -rf .terraform terraform.tfstate terraform.tfstate.backup` (if present)
  - `terraform init -reconfigure`

Common init/validate errors and fixes:

- Invalid single-argument block definition: Multi-attribute blocks (e.g., `variable`) must be multi-line. Expand attributes onto separate lines.
- Missing attribute separator in object literals: Use one attribute per line or add commas/newlines between attributes in inline objects.

## Troubleshooting: S3 State Lock (412 PreconditionFailed)

- Symptom: `terraform apply` (or `plan/init`) prints an error while acquiring the lock and fails with an S3 412 response. Example:

```
Acquiring state lock. This may take a few moments...
Error: Error acquiring the state lock

Error message: operation error S3: PutObject, https response error StatusCode: 412, ...
api error PreconditionFailed: At least one of the pre-conditions you specified did not hold
Lock Info:
  ID:        d1da81a4-c10a-59aa-2473-9ddbcdcbb01f
  Path:      tf-state-139294524816-us-east-1/staging/rds/terraform.tfstate
  Operation: OperationTypeApply
  Who:       <host>
  Version:   1.13.1
  Created:   <timestamp>
```

- Cause: Terraform v1.13 uses an S3 lockfile object to coordinate access. An interrupted run (e.g., Ctrl-C, crash, network blip) can leave a stale lockfile behind, causing a 412 until cleared.

- Resolve safely:
  - Run from the stack directory that failed (e.g., `aws-labs/09-rds`):
    - `terraform force-unlock -force <ID>`
  - If the CLI cannot unlock, delete the lock object directly, then re-init:
    - S3 key: the state key with `.tflock` suffix (e.g., `staging/rds/terraform.tfstate.tflock`)
    - `aws s3api delete-object --bucket <bucket> --key <state-key>.tflock --profile <profile>`
    - `terraform init -reconfigure`

- What success looks like:
  - Force unlock:
    - `Terraform state has been successfully unlocked!`
  - Next apply acquires a new lock and proceeds without error.

- Prevent recurrence:
  - Avoid killing Terraform mid-run; let it exit gracefully.
  - Don’t use `-lock=false` in shared environments.
  - If multiple users/automation may collide, set `-lock-timeout=5m` to wait for the existing lock.

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

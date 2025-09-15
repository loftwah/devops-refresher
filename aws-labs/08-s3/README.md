# Lab 08 – S3 (App Bucket)

## What Terraform Actually Creates (main.tf)

Related docs: `docs/terraform-resource-cheatsheet.md`

- Random suffix via `random_id.suffix` to ensure unique bucket names when not explicitly set.
- `aws_s3_bucket.this` with name `coalesce(var.bucket_name, "${var.bucket_prefix}-${random_id.suffix.hex}")`.
- `aws_s3_bucket_public_access_block` blocking all public ACLs/policies.
- `aws_s3_bucket_versioning` enabled.
- `aws_s3_bucket_server_side_encryption_configuration` with SSE-S3 (`AES256`).
- Outputs: `bucket_name`, `bucket_arn`.

There is no bucket policy in this lab because access is granted via IAM on the task role in Lab 06 to a prefix scope: `s3://<bucket>/app/*`.

## Variables (variables.tf)

- `bucket_name` (string|null): explicit name; if null, a name is generated.
- `bucket_prefix` (string): prefix used when generating the name. Default `devops-refresher-staging-app`.

## Apply

```bash
cd aws-labs/08-s3
terraform init
terraform apply -auto-approve

# Optional explicit name
# terraform apply -auto-approve -var bucket_name=my-explicit-bucket-name
```

## How Other Labs Use This

- IAM (Lab 06): auto‑detects this bucket via remote state and grants least‑priv runtime access to `app/*` objects.
- Parameter Store (Lab 11): reads `bucket_name` and writes `S3_BUCKET` for consumers.
- App endpoints: `/s3/:id` map to `s3://$S3_BUCKET/app/<id>.txt`.

## Outputs

- `bucket_name` — wire into Parameter Store `S3_BUCKET`.
- `bucket_arn` — for reference.

## Cleanup

Empty the bucket first, then:

```bash
terraform destroy -auto-approve
```

## Why It Matters

- S3 “AccessDenied” is a classic trap caused by Block Public Access, missing IAM permissions, or using the wrong path/prefix. Encryption choices (SSE‑S3 vs SSE‑KMS) impact IAM and key policies. Versioned buckets require special teardown steps.

## Mental Model

- Block Public Access (BPA) overrides bucket policies and ACLs to prevent public exposure. In labs we keep BPA on and grant access via IAM on the workload role.
- Encryption:
  - SSE‑S3 (AES256): simple, no KMS key needed; good default.
  - SSE‑KMS (CMK): stronger controls and audit via CloudTrail data events, but introduces KMS permissions and key policy considerations for producers/consumers.

## Verification

```bash
# Confirm BPA
aws s3api get-public-access-block --bucket <bucket>

# Confirm versioning and encryption
aws s3api get-bucket-versioning --bucket <bucket>
aws s3api get-bucket-encryption --bucket <bucket>

# Simple read/write using the app role/profile
aws s3 cp <local-file> s3://<bucket>/app/test.txt
aws s3 ls s3://<bucket>/app/
```

## Troubleshooting

- AccessDenied when writing: verify the caller is the app task role with `s3:PutObject` on `arn:aws:s3:::<bucket>/app/*` and that no explicit deny exists.
- AccessDenied on read: check prefix/path (case‑sensitive) and ensure IAM allows `s3:GetObject` on the same prefix.
- KMS `AccessDeniedException`: if using SSE‑KMS, grant the role `kms:Encrypt/Decrypt` and update the key policy or grant via grants.

## Teardown (Versioned Buckets)

Versioned buckets cannot be deleted until all object versions and delete markers are removed.

```bash
# Purge all versions and delete markers (requires AWS CLI v2)
aws s3api delete-objects --bucket <bucket> \
  --delete "$(aws s3api list-object-versions --bucket <bucket> \
  --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)" || true

aws s3api delete-objects --bucket <bucket> \
  --delete "$(aws s3api list-object-versions --bucket <bucket> \
  --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)" || true

# Then terraform destroy
terraform destroy -auto-approve
```

## Check Your Understanding

- When do you choose SSE‑KMS over SSE‑S3 and what IAM/KMS updates are required?
- Why keep BPA enabled even for internal buckets?
- How do you recognize a permissions issue vs a path/prefix mistake?

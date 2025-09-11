# Terraform Output Gather

This script gathers all of the Terraform outputs for `aws-labs/` and saves them into a markdown file and also as JSON.

## Cross-Stack State via `terraform_remote_state`

All labs share values via the Terraform remote state stored in S3, rather than copying outputs by hand or passing long `-var` chains. Each consumer lab reads the producer lab’s outputs using the `terraform_remote_state` data source.

### Backend/Key Convention

- Remote backend: S3 (configured in each lab’s `backend.tf`).
- State object key pattern: `<environment>/<stack>/terraform.tfstate` (for example: `staging/rds/terraform.tfstate`).
- Values are read-only to consumers; only the owning lab writes its state.

### Example: Consume RDS Outputs

```hcl
data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket       = "tf-state-<account>-<region>"
    key          = "staging/rds/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  # Prefer explicit overrides if provided, otherwise read from remote state
  db_host = length(var.db_host) > 0 ? var.db_host : data.terraform_remote_state.rds.outputs.db_host
  db_port = var.db_port > 0 ? var.db_port : tonumber(data.terraform_remote_state.rds.outputs.db_port)
  db_user = length(var.db_user) > 0 ? var.db_user : data.terraform_remote_state.rds.outputs.db_user
  db_name = length(var.db_name) > 0 ? var.db_name : data.terraform_remote_state.rds.outputs.db_name
}
```

### When to Override

- Default: rely on `terraform_remote_state` for correctness and consistency.
- Override with `*.tfvars` or `-var` only for intentional testing or exceptional cases.

### Secrets vs Non-Secrets

- Non-secrets (e.g., DB host/port/user/name) flow via remote state → then into SSM Parameter Store in the Parameter Store lab.
- Secrets (e.g., DB password) are created by the owning lab in Secrets Manager and exposed by ARN; consumers reference the ARN rather than passing secret values around.

## Troubleshooting `terraform_remote_state`

- Missing or wrong key:
  - Ensure the producing lab has been applied and the state object exists at the expected key (environment/stack path).
  - Verify the `bucket`, `key`, `region`, and `profile` values in the data source.
- Access denied:
  - Confirm AWS credentials/profile and IAM permissions allow `s3:GetObject` on the state object and `s3:ListBucket` for the bucket.
- S3 lockfile 412 during apply/plan:
  - If a previous run was interrupted, clear the stale state lock using `terraform force-unlock -force <ID>` from the failing lab directory. After success, re-run the command.
  - You can also delete the `.tflock` object for that state key via AWS CLI if needed, then `terraform init -reconfigure` and retry.

## Output Aggregation

- This directory’s script aggregates outputs across labs to a single Markdown and JSON artifact for quick reference.
- It reads each lab’s Terraform outputs (which are already published via remote state) and compiles them for humans and tooling.

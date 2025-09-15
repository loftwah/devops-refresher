# Lab 06 – IAM (CI/CD and App Roles)

Related docs: `docs/iam.md`, `docs/runbooks/cicd-ecs-permissions.md`, `docs/decisions/ADR-005-cicd-iam-ownership.md`

## What Terraform Actually Creates (main.tf)

- ECS task execution role: pull images from ECR, write logs to CloudWatch; optional KMS decrypt for logs/images.
- ECS task role: runtime application permissions (S3 prefix, SSM parameters, Secrets Manager read for specific paths, optional RDS IAM auth).
- CI/CD roles:
  - CodePipeline role with `iam:PassRole` scoped to the ECS task/execution roles and the minimum `ecs:*` actions needed for deploys.
  - CodeBuild build role for image build/push (ECR permissions, logs) and deploy role (ECS update-service, EKS describe for Helm where applicable).
- Outputs: ARNs for execution/task roles and CI/CD roles.

## Why It Matters

- Most ECS/EKS deploy failures are IAM misconfigurations: missing `iam:PassRole`, insufficient ECR/Logs, or Secrets/SSM scoping. Clear separation between execution and task roles reduces blast radius.

## Mental Model

- Execution role: used by the ECS agent to pull images and push logs. Never grant app data access here.
- Task role: used by your container. Keep to least‑privilege resources (prefix‑scoped S3, parameter paths, specific secret ARNs).
- CI roles: grant only the build/deploy actions required. Scope `iam:PassRole` to the exact task/execution roles and constrain via conditions (e.g., `ecs:UpdateService` on specific ARNs).

## Verification

```bash
# Quick role sanity
aws iam get-role --role-name <exec-role-name> --query 'Role.Arn'
aws iam get-role --role-name <task-role-name> --query 'Role.Arn'

# Check PassRole permissions (pipeline role)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<acct>:role/<pipeline-role> \
  --action-names iam:PassRole ecs:UpdateService \
  --resource-arns arn:aws:iam::<acct>:role/<exec-role> arn:aws:iam::<acct>:role/<task-role>

# ECR push/pull permissions (build role)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<acct>:role/<codebuild-role> \
  --action-names ecr:GetAuthorizationToken ecr:BatchCheckLayerAvailability ecr:PutImage
```

## Troubleshooting

- AccessDenied on deploy: missing or unscoped `iam:PassRole` to ECS; ensure both task and execution roles are allowed and conditionally limited to ECS use.
- Cannot pull image / no logs: execution role is missing ECR read or CloudWatch Logs write.
- Secret/parameter fetch fails: task role missing Secrets Manager or SSM path permissions, or KMS `Decrypt` where SSE‑KMS is used.

## Teardown

- Ensure no running services reference these roles. Detach inline/managed policies if deletion is blocked; destroy CI stacks before IAM to avoid dependencies.

## Check Your Understanding

- What are the distinct responsibilities of the execution role vs the task role?
- How do you safely scope `iam:PassRole` for a pipeline that deploys to ECS?
- When does the task role need `kms:Decrypt` and on which resources?

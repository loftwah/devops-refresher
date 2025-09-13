# ECS Exec: Requirements and How This Repo Ensures Them

This repo automates everything needed for ECS Exec on Fargate. If Exec fails, something drifted. Bring Terraform down/up and it will be fixed.

## What ECS Exec Needs

1. ECS service with `enable_execute_command = true`.
2. IAM permissions on the running task to open SSM channels:
   - We attach the AWS managed policy `AmazonSSMManagedInstanceCore` to BOTH:
     - Task role `devops-refresher-staging-app-task`
     - Execution role `devops-refresher-staging-ecs-execution`
3. Network path from tasks to SSM services:
   - Private subnets with NAT OR
   - VPC Interface Endpoints with Private DNS for: `ssm`, `ssmmessages`, `ec2messages`.
4. A shell in your container image (Alpine has `/bin/sh`).

## Where This Is Defined in Terraform

- IAM roles and the SSM managed policy attachments:
  - `aws-labs/06-iam/main.tf`
- ECS service enabling Exec and wiring roles:
  - `aws-labs/14-ecs-service/main.tf` (`enable_execute_command = true`)
- VPC interface endpoints (SSM/ECR/Logs) and endpoint SG:
  - `aws-labs/02-vpc-endpoints/main.tf`

## Lab Cross‑Links

- Lab 02 (VPC Endpoints): ensures `ssm`, `ssmmessages`, `ec2messages` interface endpoints exist with Private DNS.
- Lab 06 (IAM): attaches `AmazonSSMManagedInstanceCore` to task and execution roles.
- Lab 14 (ECS Service): sets `enable_execute_command = true` and uses the IAM roles.

## Validate (Automated)

Run all validators:

```bash
aws-labs/scripts/validate-labs.sh
```

To run only the ECS Exec validator:

```bash
aws-labs/scripts/validate-ecs-exec.sh
```

## One-line usage

- Open a shell into the first RUNNING task:

```bash
aws-labs/scripts/ecs-exec.sh
```

- Or pass a specific task ID/ARN:

```bash
aws-labs/scripts/ecs-exec.sh aa0c7c8f33e94cd4853ee4233a3bc551
```

The validator confirms:

- Exec flag on service is ON
- Task and execution roles have `AmazonSSMManagedInstanceCore`
- SSM interface endpoints exist and have Private DNS enabled
- Cluster has a RUNNING task and platform version supports Exec

## If Exec Still Fails

- Re-apply Lab 02, 06, and 14. No manual IAM or endpoint edits should be necessary.
- Ensure the container has `/bin/sh` or `/bin/bash` and the service redeployed after IAM changes.

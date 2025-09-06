# Practice Questions & Answers (ECS + Terraform)

## Terraform

- Q: Why use an S3 backend with DynamoDB locking?
  A: Remote state enables collaboration and locking prevents concurrent state writes that corrupt state.

- Q: Workspaces or separate states?
  A: Separate states per environment isolate blast radius and simplify RBAC; workspaces are fine for simple cases.

- Q: How do you import an existing ALB into Terraform?
  A: Create a minimal `aws_lb` resource, then `terraform import aws_lb.main <lb-arn>`; expand attributes incrementally, confirm `plan` shows no changes.

- Q: How to avoid leaking secrets into Terraform state?
  A: Do not put secrets in TF variables used by resources that store full values in state; use SSM/Secrets Manager and reference ARNs/parameter names; mark vars `sensitive`.

## AWS Networking & ALB

- Q: Why private subnets for ECS tasks?
  A: Reduce exposure; tasks sit behind ALB, egress via NAT; only ALB is public.

- Q: What determines ALB target health?
  A: Target group health checks (path, interval, thresholds) and the task/container responding on the right port.

## ECS

- Q: Task execution role vs task role?
  A: Execution role lets ECS pull images and write logs; task role is assumed by the app code for runtime AWS access.

- Q: Fargate vs EC2 launch type?
  A: Fargate is serverless (no instance mgmt) with per-task pricing; EC2 gives more control/cost efficiency at scale.

- Q: How do you roll back a bad deployment?
  A: Redeploy the previous image tag or task definition revision; with circuit breaker, failed deploys auto-rollback.

- Q: How do you pass secrets to containers?
  A: Use task definition `secrets` referencing SSM/Secrets Manager, not plain `environment`.

## CI/CD

- Q: What are typical CodePipeline stages for ECS?
  A: Source → Build (Docker + push) → Deploy (update task def image) → Post-deploy checks/approvals.

## Monitoring & Ops

- Q: Where do you start when the service is unhealthy?
  A: Check target group health + ALB 5XX; review ECS events and container logs; verify env variables and secret access.

- Q: How do you debug `ResourceInitializationError` on ECS Fargate?
  A: Check execution role permissions for ECR and CloudWatch logs; ensure private subnets have NAT for egress.

## Design & Safety

- Q: Why iterate one resource at a time?
  A: Faster feedback, simpler rollbacks, reduced blast radius, easier review.

- Q: How do you structure modules for multi-env?
  A: Shared modules with env-specific stacks wrapping them; pass minimal inputs; keep outputs stable.

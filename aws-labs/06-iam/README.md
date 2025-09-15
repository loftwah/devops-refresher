# Lab 06 – IAM (CI/CD and App Roles)

- Provides ECS task/execution roles and CI/CD roles used by labs 15 and 20.
- Includes `eks:DescribeCluster` on the CodeBuild role so Helm deploys can run `aws eks update-kubeconfig`.
- CodePipeline role has permissions for ECS deploy and CodeBuild start; CodeBuild has ECR and logging permissions.

No shell exports required; providers and backends are pinned in each lab.

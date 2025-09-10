# IAM For Our Environment

## Objectives

- Provide least-privilege IAM for both ECS and EKS workloads.
- Enable EKS IRSA (IAM Roles for Service Accounts) to avoid node-bound credentials.
- Scope runtime access to SSM Parameter Store and Secrets Manager by environment and service.

## Scope & Naming

- App name: `devops-refresher`; Environments: `staging` (extend as needed).
- Parameter/secret path convention: `/devops-refresher/<env>/<service>/<key>`.

## Tasks

1) ECS Roles

- Task execution role (pull images, write logs):
  - Trust: `ecs-tasks.amazonaws.com`.
  - Policy: attach AWS managed `service-role/AmazonECSTaskExecutionRolePolicy`.
  - Optionally add: `ecr:GetAuthorizationToken` (already covered), KMS decrypt if logs are encrypted.

- Task role (app runtime):
  - Trust: `ecs-tasks.amazonaws.com`.
  - Inline/attached policy: least-privilege read to required SSM parameter paths and Secrets Manager ARNs used by the task.

Terraform sketch:

```hcl
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-exec-devops-refresher"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "ecs-task-devops-refresher"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ecs-tasks.amazonaws.com"] }
  }
}

data "aws_iam_policy_document" "ecs_task_runtime" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/devops-refresher/${var.env}/*"]
  }
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [for s in var.secret_arns : s]
  }
}

resource "aws_iam_policy" "ecs_task_runtime" {
  name   = "ecs-task-runtime-devops-refresher"
  policy = data.aws_iam_policy_document.ecs_task_runtime.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_runtime" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_task_runtime.arn
}
```

2) EKS Prereqs: Cluster OIDC Provider

- Create or reference the cluster OIDC provider so pods can assume roles via IRSA.

```hcl
data "aws_eks_cluster" "this" { name = var.cluster_name }
data "aws_eks_cluster_auth" "this" { name = var.cluster_name }

resource "aws_iam_openid_connect_provider" "this" {
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.oidc_thumbprint]
}
```

3) EKS: IRSA Roles per Service Account

- App runtime role (namespace `app`, service account `web`):
  - Trust: federated with the cluster OIDC provider.
  - Condition restricts to `system:serviceaccount:app:web` and `aud` = `sts.amazonaws.com`.
  - Policy: read-only to required SSM parameter paths and Secrets Manager ARNs.

```hcl
data "aws_iam_policy_document" "app_irsa_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals { type = "Federated" identifiers = [aws_iam_openid_connect_provider.this.arn] }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:app:web"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_irsa" {
  name               = "eks-app-web-devops-refresher"
  assume_role_policy = data.aws_iam_policy_document.app_irsa_trust.json
}

data "aws_iam_policy_document" "app_irsa_policy" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/devops-refresher/${var.env}/*"]
  }
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [for s in var.secret_arns : s]
  }
}

resource "aws_iam_policy" "app_irsa_policy" {
  name   = "eks-app-web-runtime"
  policy = data.aws_iam_policy_document.app_irsa_policy.json
}

resource "aws_iam_role_policy_attachment" "app_irsa_attach" {
  role       = aws_iam_role.app_irsa.name
  policy_arn = aws_iam_policy.app_irsa_policy.arn
}
```

Kubernetes service account annotation:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web
  namespace: app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<acct-id>:role/eks-app-web-devops-refresher
```

4) EKS Node Group Instance Profile

- Attach AWS-managed policies to the node role:
  - `AmazonEKSWorkerNodePolicy`
  - `AmazonEKS_CNI_Policy`
  - `AmazonEC2ContainerRegistryReadOnly`
  - Optionally: `CloudWatchAgentServerPolicy`

5) Common Controllers (if used)

- AWS Load Balancer Controller: create an IRSA role and attach the recommended policy from the project docs.
- ExternalDNS: read Route53 and list hosted zones (scoped to your zone IDs).
- Cluster Autoscaler: scale node groups (scoped to your cluster).
- EBS CSI driver: attach the recommended policy.
- Secrets Store CSI driver (ASCP): allow `GetSecretValue` and/or `GetParameter*` for the required ARNs/paths.

## Acceptance Criteria

- ECS tasks pull from ECR and write to CloudWatch Logs.
- ECS tasks/pods can read only the SSM parameter paths and secret ARNs they need.
- EKS pods assume IRSA roles successfully (verify with `aws sts get-caller-identity`).

## Hints

- Start from AWS managed policies, then tighten to your exact ARNs/paths.
- Scope SSM by parameter path prefix and Secrets Manager by exact secret ARNs.
- Keep trust policies strict: limit IRSA to specific `namespace:serviceaccount` pairs.

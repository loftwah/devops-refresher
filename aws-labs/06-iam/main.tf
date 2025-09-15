data "aws_caller_identity" "current" {}

# Read S3 lab remote state so we can automatically grant task role access
# to the app bucket without having to pass -var s3_bucket_name=...
data "terraform_remote_state" "s3" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/s3/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  s3_bucket_name_effective = length(var.s3_bucket_name) > 0 ? var.s3_bucket_name : try(data.terraform_remote_state.s3.outputs.bucket_name, "")
}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "devops-refresher-staging-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_execution_extra" {
  dynamic "statement" {
    for_each = var.grant_exec_role_secrets_read ? [1] : []
    content {
      effect  = "Allow"
      actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      resources = [
        "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_path_prefix}/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.grant_exec_role_ssm_read && length(var.ssm_path_prefix) > 0 ? [1] : []
    content {
      effect  = "Allow"
      actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
      resources = [
        "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_path_prefix}/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = length(var.kms_key_arn) > 0 ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_policy" "ecs_execution_extra" {
  name   = "devops-refresher-staging-ecs-execution-extra"
  policy = data.aws_iam_policy_document.ecs_execution_extra.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_extra" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.ecs_execution_extra.arn
}

resource "aws_iam_role" "task" {
  name               = "devops-refresher-staging-app-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

data "aws_iam_policy_document" "task_s3" {
  count = length(local.s3_bucket_name_effective) > 0 ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.s3_bucket_name_effective}/app/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.s3_bucket_name_effective}"]
  }
}

resource "aws_iam_policy" "task_s3" {
  count  = length(local.s3_bucket_name_effective) > 0 ? 1 : 0
  name   = "devops-refresher-staging-task-s3"
  policy = data.aws_iam_policy_document.task_s3[0].json
}

resource "aws_iam_role_policy_attachment" "task_s3" {
  count      = length(local.s3_bucket_name_effective) > 0 ? 1 : 0
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_s3[0].arn
}

data "aws_iam_policy_document" "task_ssm" {
  count = var.grant_task_role_ssm_read && length(var.ssm_path_prefix) > 0 ? 1 : 0
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_path_prefix}/*"]
  }
}

resource "aws_iam_policy" "task_ssm" {
  count  = var.grant_task_role_ssm_read && length(var.ssm_path_prefix) > 0 ? 1 : 0
  name   = "devops-refresher-staging-task-ssm"
  policy = data.aws_iam_policy_document.task_ssm[0].json
}

resource "aws_iam_role_policy_attachment" "task_ssm" {
  count      = var.grant_task_role_ssm_read && length(var.ssm_path_prefix) > 0 ? 1 : 0
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_ssm[0].arn
}

resource "aws_iam_role_policy_attachment" "task_ssm_managed_core" {
  role       = aws_iam_role.task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_ssm_managed_core" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

output "execution_role_arn" { value = aws_iam_role.ecs_execution.arn }
output "task_role_arn" { value = aws_iam_role.task.arn }
output "task_role_name" { value = aws_iam_role.task.name }

# --- CI/CD Roles ---

data "aws_iam_policy_document" "codebuild_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "devops-refresher-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_trust.json
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages"
    ]
    resources = ["*"]
  }

  # Allow EKS kubeconfig generation in CodeBuild deploy stages
  statement {
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codebuild_inline" {
  name   = "devops-refresher-codebuild"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

data "aws_iam_policy_document" "codepipeline_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "devops-refresher-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_trust.json
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    # Allow any CodeBuild project in this account/region
    resources = ["arn:aws:codebuild:${var.region}:${data.aws_caller_identity.current.account_id}:project/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [var.connection_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecs:ListClusters",
      "ecs:DescribeClusters",
      "ecs:ListServices",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTaskDefinitions",
      "ecs:DescribeTasks",
      "ecs:DescribeTaskSets",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService"
    ]
    resources = ["*"]
  }

  # Break-glass: broad ECS allow to unblock deploys when troubleshooting
  statement {
    effect    = "Allow"
    actions   = ["ecs:*"]
    resources = ["*"]
  }

  # Restrict PassRole to only the ECS task and execution roles, and only when passed to ECS tasks
  # Break-glass: unconditional PassRole to unblock deploys
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codepipeline_inline" {
  name   = "devops-refresher-codepipeline"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

output "codebuild_role_arn" { value = aws_iam_role.codebuild.arn }
output "codepipeline_role_arn" { value = aws_iam_role.codepipeline.arn }

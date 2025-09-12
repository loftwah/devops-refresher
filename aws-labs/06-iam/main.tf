data "aws_caller_identity" "current" {}

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
  count = length(var.s3_bucket_name) > 0 ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}/app/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}"]
  }
}

resource "aws_iam_policy" "task_s3" {
  count  = length(var.s3_bucket_name) > 0 ? 1 : 0
  name   = "devops-refresher-staging-task-s3"
  policy = data.aws_iam_policy_document.task_s3[0].json
}

resource "aws_iam_role_policy_attachment" "task_s3" {
  count      = length(var.s3_bucket_name) > 0 ? 1 : 0
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

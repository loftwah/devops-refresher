locals {
  oidc_sub = replace(var.oidc_provider_url, "https://", "")
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals { type = "Federated" identifiers = [var.oidc_provider_arn] }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_sub}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_sub}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "read" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_path_prefix}/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_prefix}-*"
    ]
  }
}

resource "aws_iam_policy" "read" {
  name   = "ExternalSecretsReadConfig"
  policy = data.aws_iam_policy_document.read.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.read.arn
}


data "aws_caller_identity" "current" {}

# CodeBuild role
resource "aws_iam_role" "codebuild" {
  name               = "demo-app-codebuild"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

data "aws_iam_policy_document" "codebuild_inline" {
  statement {
    actions = [
      "logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents",
      "ecr:GetAuthorizationToken","ecr:BatchCheckLayerAvailability","ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer","ecr:InitiateLayerUpload","ecr:PutImage","ecr:UploadLayerPart"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codebuild_inline" {
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_inline.json
}

resource "aws_codebuild_project" "build" {
  name          = "demo-app-build"
  service_role  = aws_iam_role.codebuild.arn
  description   = "Builds Docker image and pushes to ECR; emits imagedefinitions.json"
  build_timeout = 20

  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable = [
      { name = "ECR_REPOSITORY", value = var.ecr_repository_url },
      { name = "AWS_DEFAULT_REGION", value = var.region }
    ]
  }
  source { type = "CODEPIPELINE" }
  cache { type = "NO_CACHE" }
  tags = var.tags
}

# CodePipeline role
resource "aws_iam_role" "codepipeline" {
  name               = "demo-app-codepipeline"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "codepipeline.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

data "aws_iam_policy_document" "codepipeline_inline" {
  statement { actions = ["s3:*"], resources = ["*"] }
  statement { actions = ["codebuild:BatchGetBuilds","codebuild:StartBuild"], resources = [aws_codebuild_project.build.arn] }
  statement { actions = ["iam:PassRole"], resources = [aws_iam_role.codebuild.arn, aws_iam_role.codepipeline.arn] }
  statement { actions = ["ecs:DescribeServices","ecs:DescribeTaskDefinition","ecs:RegisterTaskDefinition","ecs:UpdateService"], resources = ["*"] }
}

resource "aws_iam_role_policy" "codepipeline_inline" {
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline_inline.json
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "cp-artifacts-${data.aws_caller_identity.current.account_id}-${var.region}"
  force_destroy = true
  tags          = merge(var.tags, { Name = "cp-artifacts" })
}

resource "aws_codestarconnections_connection" "github" {
  count       = var.codestar_connection_arn == "" ? 1 : 0
  name        = "github-connection"
  provider_type = "GitHub"
  tags        = var.tags
}

locals {
  connection_arn = var.codestar_connection_arn != "" ? var.codestar_connection_arn : aws_codestarconnections_connection.github[0].arn
}

resource "aws_codepipeline" "ecs_pipeline" {
  name     = "demo-app-ecs"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store { location = aws_s3_bucket.artifacts.bucket type = "S3" }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]
      configuration = {
        ConnectionArn    = local.connection_arn
        FullRepositoryId  = var.github_full_repo_id
        BranchName        = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]
      version          = "1"
      configuration    = { ProjectName = aws_codebuild_project.build.name }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "DeployECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["BuildOutput"]
      version         = "1"
      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  tags = var.tags
}

# Optional: EventBridge to Slack notifier
resource "aws_cloudwatch_event_rule" "cb_rule" {
  count = var.slack_notifier_arn == "" ? 0 : 1
  name  = "notify-codebuild"
  event_pattern = jsonencode({
    "source": ["aws.codebuild"],
    "detail-type": ["CodeBuild Build State Change"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cb_target" {
  count     = var.slack_notifier_arn == "" ? 0 : 1
  rule      = aws_cloudwatch_event_rule.cb_rule[0].name
  target_id = "slack-notifier"
  arn       = var.slack_notifier_arn
}

resource "aws_cloudwatch_event_rule" "cp_rule" {
  count = var.slack_notifier_arn == "" ? 0 : 1
  name  = "notify-codepipeline"
  event_pattern = jsonencode({
    "source": ["aws.codepipeline"],
    "detail-type": ["CodePipeline Pipeline Execution State Change", "CodePipeline Stage Execution State Change"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cp_target" {
  count     = var.slack_notifier_arn == "" ? 0 : 1
  rule      = aws_cloudwatch_event_rule.cp_rule[0].name
  target_id = "slack-notifier"
  arn       = var.slack_notifier_arn
}

output "connection_arn" { value = local.connection_arn }


data "aws_caller_identity" "current" {}

data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/iam/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-sandbox"
    use_lockfile = true
    encrypt      = true
  }
}

resource "random_id" "artifacts" {
  count       = var.create_artifacts_bucket && var.artifacts_bucket_randomize ? 1 : 0
  byte_length = 3
}

locals {
  tags = var.tags

  inline_buildspec_default = <<-YAML
    version: 0.2
    env:
      variables:
        IMAGE_REPO_NAME: "${var.ecr_repo_name}"
        APP_ENV: "staging"
    phases:
      install:
        runtime-versions:
          nodejs: 20
        commands:
          - npm ci --no-audit --no-fund
      pre_build:
        commands:
          - npm run build
          - echo Logging in to Amazon ECR...
          - aws --version
          - ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          - REGION=$${AWS_REGION:-$${AWS_DEFAULT_REGION:-ap-southeast-2}}
          - REPO_URI=$${ACCOUNT_ID}.dkr.ecr.$${REGION}.amazonaws.com/$${IMAGE_REPO_NAME}
          - aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $${ACCOUNT_ID}.dkr.ecr.$${REGION}.amazonaws.com
          - GIT_SHA=$(echo $${CODEBUILD_RESOLVED_SOURCE_VERSION} | cut -c1-7)
      build:
        commands:
          - echo Build started on `date`
          - |
            docker build \
              --platform=linux/amd64 \
              -t $${REPO_URI}:staging \
              -t $${REPO_URI}:$${GIT_SHA} \
              .
      post_build:
        commands:
          - echo Build completed on `date`
          - docker push $${REPO_URI}:staging
          - docker push $${REPO_URI}:$${GIT_SHA}
          - printf '[{"name":"app","imageUri":"%s"}]' $${REPO_URI}:$${GIT_SHA} > imagedefinitions.json
    artifacts:
      files:
        - imagedefinitions.json
  YAML

  inline_buildspec_effective = length(var.inline_buildspec_override) > 0 ? var.inline_buildspec_override : local.inline_buildspec_default

  # Artifacts bucket naming/ARN (supports create vs reuse and optional random suffix)
  artifacts_bucket_name_effective = var.create_artifacts_bucket ? (
    var.artifacts_bucket_randomize ? "${var.artifacts_bucket_name}-${random_id.artifacts[0].hex}" : var.artifacts_bucket_name
  ) : var.artifacts_bucket_name
  artifacts_bucket_arn_effective = "arn:aws:s3:::${local.artifacts_bucket_name_effective}"
}

resource "aws_s3_bucket" "artifacts" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = local.artifacts_bucket_name_effective
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id
  versioning_configuration { status = "Enabled" }
}


resource "aws_codebuild_project" "app" {
  name         = "devops-refresher-app-build"
  description  = "Builds and pushes demo-node-app image; outputs imagedefinitions.json"
  service_role = data.terraform_remote_state.iam.outputs.codebuild_role_arn

  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.ecr_repo_name
    }
    environment_variable {
      name  = "APP_ENV"
      value = "staging"
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = var.use_inline_buildspec ? local.inline_buildspec_effective : null
  }
  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.expected_account_id
      error_message = "Wrong AWS account. Expected ${var.expected_account_id}, got ${data.aws_caller_identity.current.account_id}. Set AWS_PROFILE=devops-sandbox."
    }
    precondition {
      condition     = var.region == "ap-southeast-2"
      error_message = "Wrong region for resources. Expected ap-southeast-2."
    }
  }
  tags = local.tags
}


resource "aws_s3_bucket_policy" "artifacts_access" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPipelineAccess",
        Effect    = "Allow",
        Principal = { AWS = data.terraform_remote_state.iam.outputs.codepipeline_role_arn },
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ],
        Resource = [
          local.artifacts_bucket_arn_effective,
          "${local.artifacts_bucket_arn_effective}/*"
        ]
      },
      {
        Sid       = "AllowCodeBuildAccess",
        Effect    = "Allow",
        Principal = { AWS = data.terraform_remote_state.iam.outputs.codebuild_role_arn },
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ],
        Resource = [
          local.artifacts_bucket_arn_effective,
          "${local.artifacts_bucket_arn_effective}/*"
        ]
      },
      {
        Sid    = "AllowGetBucketVersioning",
        Effect = "Allow",
        Principal = { AWS = [
          data.terraform_remote_state.iam.outputs.codepipeline_role_arn,
          data.terraform_remote_state.iam.outputs.codebuild_role_arn
        ] },
        Action   = ["s3:GetBucketVersioning"],
        Resource = local.artifacts_bucket_arn_effective
      }
    ]
  })
}

resource "aws_codepipeline" "app" {
  # Ensure the artifacts bucket is fully created and versioned before pipeline validation runs
  depends_on = [aws_s3_bucket_versioning.artifacts]
  name       = "devops-refresher-app-pipeline"
  role_arn   = data.terraform_remote_state.iam.outputs.codepipeline_role_arn

  artifact_store {
    location = local.artifacts_bucket_name_effective
    type     = "S3"
  }
  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.expected_account_id
      error_message = "Wrong AWS account. Expected ${var.expected_account_id}, got ${data.aws_caller_identity.current.account_id}. Set AWS_PROFILE=devops-sandbox."
    }
    precondition {
      condition     = var.region == "ap-southeast-2"
      error_message = "Wrong region for resources. Expected ap-southeast-2."
    }
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_out"]
      configuration = {
        ConnectionArn    = var.connection_arn
        FullRepositoryId = var.repo_full_name
        BranchName       = var.branch
        DetectChanges    = "true"
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
      input_artifacts  = ["source_out"]
      output_artifacts = ["build_out"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.app.name
      }
    }
  }

  stage {
    name = "Approval"
    action {
      name     = "ManualApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        CustomData = "Approve deploy to ECS staging"
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_out"]
      version         = "1"
      configuration = {
        ClusterName = var.cluster_name
        ServiceName = var.service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  tags = local.tags
}

output "pipeline_name" { value = aws_codepipeline.app.name }
output "codebuild_project" { value = aws_codebuild_project.app.name }
output "artifacts_bucket_name" { value = local.artifacts_bucket_name_effective }

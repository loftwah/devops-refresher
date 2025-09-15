data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/iam/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "alb_dns_cert" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/eks-alb-externaldns/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

data "terraform_remote_state" "eks_app" {
  backend = "s3"
  config = {
    bucket       = "tf-state-139294524816-us-east-1"
    key          = "staging/eks-app/terraform.tfstate"
    region       = "us-east-1"
    profile      = var.aws_profile
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  cert_arn          = try(data.terraform_remote_state.alb_dns_cert.outputs.certificate_arn, "")
  app_irsa_role_arn = try(data.terraform_remote_state.eks_app.outputs.app_irsa_role_arn, "")
  inline_buildspec  = <<-YAML
    version: 0.2
    env:
      variables:
        AWS_REGION: ${var.region}
        CLUSTER_NAME: ${var.cluster_name}
        NAMESPACE: ${var.namespace}
        RELEASE_NAME: ${var.release_name}
        CHART_PATH: ${var.chart_path}
        VALUES_FILE: ${var.values_file}
        ECR_REPO_NAME: ${var.ecr_repo_name}
        CERT_ARN: ${local.cert_arn}
        APP_IRSA_ROLE_ARN: ${local.app_irsa_role_arn}
        USE_PATH_GUARD: "false"   # set to "true" to enable diff-based short-circuit
    phases:
      install:
        runtime-versions:
          docker: 20
        commands:
          - curl -sSL -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-08-07/bin/linux/amd64/kubectl
          - chmod +x /usr/local/bin/kubectl
          - curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      pre_build:
        commands:
          - ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          - REPO_URI=$${ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com/$${ECR_REPO_NAME}
          - GIT_SHA=$(echo $${CODEBUILD_RESOLVED_SOURCE_VERSION} | cut -c1-7)
          - |
            if [[ "$USE_PATH_GUARD" == "true" ]]; then
              if [ -d .git ]; then
                set +e
                CHANGED=$(git diff --name-only HEAD~1 HEAD | grep -E '^(aws-labs/kubernetes/|kubernetes/)' || true)
                set -e
                if [[ -z "$CHANGED" ]]; then
                  echo "No Kubernetes path changes detected; proceeding anyway to keep environments in sync"
                else
                  echo "Kubernetes changes detected:"
                  printf "%s\n" "$CHANGED"
                fi
              else
                echo "Path guard enabled, but no git metadata present (CodePipeline source is an archive). Skipping guard."
              fi
            fi
          - |
            echo "Waiting for ECR image $REPO_URI:$GIT_SHA to exist..."
            for i in {1..60}; do
              if aws ecr describe-images --repository-name "$ECR_REPO_NAME" --image-ids imageTag="$GIT_SHA" >/dev/null 2>&1; then
                echo "Found image tag: $GIT_SHA"; break; fi; sleep 10; done
          - aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
          - helm version && kubectl version --client=true
      build:
        commands:
          - helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
              -n "$NAMESPACE" --create-namespace \
              -f "$VALUES_FILE" \
              --set image.repository="$REPO_URI" \
              --set image.tag="$GIT_SHA" \
              --set ingress.certificateArn="$CERT_ARN" \
              --set serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"="$APP_IRSA_ROLE_ARN"
      post_build:
        commands:
          - kubectl -n "$NAMESPACE" rollout status deploy/"$RELEASE_NAME" --timeout=5m
  YAML
}

resource "aws_codebuild_project" "eks_deploy" {
  name         = "devops-refresher-eks-deploy"
  description  = "Deploys Helm chart to EKS with image tag from commit"
  service_role = data.terraform_remote_state.iam.outputs.codebuild_role_arn

  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = local.inline_buildspec
  }
}

resource "aws_codepipeline" "eks" {
  name     = "devops-refresher-app-eks-pipeline"
  role_arn = data.terraform_remote_state.iam.outputs.codepipeline_role_arn

  artifact_store {
    location = aws_s3_bucket.artifacts.id
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = var.connection_arn
        FullRepositoryId = var.repo_full_name
        BranchName       = var.branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "DeployEKS"
    action {
      name            = "HelmDeploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = aws_codebuild_project.eks_deploy.name
      }
    }
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "devops-refresher-eks-pipeline-artifacts"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_policy" "artifacts_access" {
  bucket = aws_s3_bucket.artifacts.id
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
          "arn:aws:s3:::${aws_s3_bucket.artifacts.id}",
          "arn:aws:s3:::${aws_s3_bucket.artifacts.id}/*"
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
          "arn:aws:s3:::${aws_s3_bucket.artifacts.id}",
          "arn:aws:s3:::${aws_s3_bucket.artifacts.id}/*"
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
        Resource = "arn:aws:s3:::${aws_s3_bucket.artifacts.id}"
      }
    ]
  })
}

output "pipeline_name" { value = aws_codepipeline.eks.name }
output "codebuild_project" { value = aws_codebuild_project.eks_deploy.name }

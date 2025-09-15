#!/usr/bin/env bash
set -Eeuo pipefail

# Validates Lab 21 – CI/CD for EKS
# - Pipeline and CodeBuild project exist
# - IAM roles exist; CodeBuild role can DescribeCluster

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

PROFILE="devops-sandbox"
REGION="ap-southeast-2"
PIPELINE_NAME="devops-refresher-eks-pipeline"
PROJECT_NAME="devops-refresher-eks-deploy"

aws_cli() {
  aws --profile "$PROFILE" --region "$REGION" "$@"
}

read_tf_outputs() {
  require terraform; require jq
  local iam_dir eks_cd_dir
  iam_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/../06-iam && pwd)"
  eks_cd_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/../21-cicd-eks-pipeline && pwd)"
  terraform -chdir="$iam_dir" init -input=false >/dev/null || true
  local iam_out
  iam_out=$(terraform -chdir="$iam_dir" output -json 2>/dev/null || echo '{}')
  CODEPIPELINE_ROLE_ARN=$(jq -r '.codepipeline_role_arn.value // empty' <<<"$iam_out" || echo '')
  CODEBUILD_ROLE_ARN=$(jq -r '.codebuild_role_arn.value // empty' <<<"$iam_out" || echo '')
  terraform -chdir="$eks_cd_dir" init -input=false >/dev/null || true
}

check_pipeline() {
  local name
  name=$(aws_cli codepipeline get-pipeline --name "$PIPELINE_NAME" --query 'pipeline.name' --output text 2>/dev/null || echo '')
  [[ "$name" == "$PIPELINE_NAME" ]] || { err "Pipeline not found: $PIPELINE_NAME"; exit 1; }
  ok "Pipeline present: $PIPELINE_NAME"
}

check_codebuild() {
  local name
  name=$(aws_cli codebuild batch-get-projects --names "$PROJECT_NAME" --query 'projects[0].name' --output text 2>/dev/null || echo '')
  [[ "$name" == "$PROJECT_NAME" ]] || { err "CodeBuild project not found: $PROJECT_NAME"; exit 1; }
  ok "CodeBuild project present: $PROJECT_NAME"
}

check_iam() {
  require jq
  [[ -n "${CODEBUILD_ROLE_ARN:-}" ]] || { info "CodeBuild role ARN not found in Lab 06 outputs; skipping IAM simulation"; return; }
  local sim
  sim=$(aws_cli iam simulate-principal-policy \
    --policy-source-arn "$CODEBUILD_ROLE_ARN" \
    --action-names eks:DescribeCluster \
    --output json)
  local decision
  decision=$(jq -r '.EvaluationResults[0].EvalDecision' <<<"$sim")
  [[ "$decision" == "allowed" || "$decision" == "Allowed" ]] || { err "CodeBuild role lacks eks:DescribeCluster"; exit 1; }
  ok "CodeBuild role can eks:DescribeCluster"
}

main() {
  require aws; require jq
  read_tf_outputs
  check_pipeline
  check_codebuild
  check_iam
  ok "EKS CI/CD validation passed"
}

main "$@"


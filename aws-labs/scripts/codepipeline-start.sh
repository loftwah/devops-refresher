#!/usr/bin/env bash
set -Eeuo pipefail

# Kick off CodePipeline executions using enforced lab account/profile/region.
# Usage:
#   ./codepipeline-start.sh               # starts both ECS and EKS pipelines
#   ./codepipeline-start.sh --only ecs    # starts only ECS
#   ./codepipeline-start.sh --only eks    # starts only EKS
#   ./codepipeline-start.sh <pipeline>    # legacy: starts named pipeline

# Defaults
PROFILE="devops-sandbox"
REGION="ap-southeast-2"
ECS_PIPELINE="devops-refresher-app-pipeline"
EKS_PIPELINE="devops-refresher-eks-pipeline"
ONLY=""

# Parse args
if [[ ${1:-} == "--only" && -n ${2:-} ]]; then
  ONLY="$2"; shift 2
elif [[ ${1:-} == "--only" ]]; then
  echo "--only requires value: ecs|eks" >&2; exit 1
fi

# Legacy single-pipeline invocation still supported
LEGACY_PIPELINE_NAME=${1:-}

aws_call() { aws "$@" --profile "$PROFILE" --region "$REGION"; }

start_pipeline() {
  local name="$1"
  echo "Starting pipeline: $name (region: $REGION, profile: $PROFILE)" >&2
  aws_call codepipeline get-pipeline --name "$name" >/dev/null 2>&1 || {
    echo "Error: Pipeline '$name' not found in $REGION." >&2; return 2; }
  aws_call codepipeline start-pipeline-execution --name "$name" --query 'pipelineExecutionId' --output text
}

if [[ -n "$LEGACY_PIPELINE_NAME" ]]; then
  start_pipeline "$LEGACY_PIPELINE_NAME"
  exit 0
fi

case "$ONLY" in
  ecs)
    start_pipeline "$ECS_PIPELINE" ;;
  eks)
    start_pipeline "$EKS_PIPELINE" ;;
  "")
    ecs_id=$(start_pipeline "$ECS_PIPELINE") || true
    eks_id=$(start_pipeline "$EKS_PIPELINE") || true
    echo "ECS_EXEC_ID=${ecs_id:-}"; echo "EKS_EXEC_ID=${eks_id:-}" ;;
  *)
    echo "Invalid --only value: $ONLY (expected ecs or eks)" >&2; exit 1 ;;

esac

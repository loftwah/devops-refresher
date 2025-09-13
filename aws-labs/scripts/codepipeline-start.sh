#!/usr/bin/env bash
set -Eeuo pipefail

# Kick off a CodePipeline execution using the enforced lab account/profile/region.
# Usage: ./codepipeline-start.sh [pipeline-name]

PIPELINE_NAME=${1:-${PIPELINE_NAME:-devops-refresher-app-pipeline}}

# Enforced lab context
PROFILE="devops-sandbox"
REGION="ap-southeast-2"

if [[ -z "$PIPELINE_NAME" ]]; then
  echo "Error: PIPELINE_NAME is required" >&2
  exit 1
fi

aws_call() {
  aws "$@" --profile "$PROFILE" --region "$REGION"
}

# Show context
echo "Starting pipeline: $PIPELINE_NAME (region: $REGION, profile: $PROFILE)" >&2

# Ensure pipeline exists to fail fast
aws_call codepipeline get-pipeline --name "$PIPELINE_NAME" >/dev/null 2>&1 || {
  echo "Error: Pipeline '$PIPELINE_NAME' not found in region '$REGION' (profile: $PROFILE)." >&2
  exit 2
}

EXEC_ID=$(aws_call codepipeline start-pipeline-execution \
  --name "$PIPELINE_NAME" \
  --query 'pipelineExecutionId' --output text)

echo "$EXEC_ID"

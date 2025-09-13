#!/usr/bin/env bash
set -Eeuo pipefail

# Verify a CodePipeline execution completes successfully using enforced lab account/profile/region.
# Usage: ./verify-pipeline.sh [pipeline-name] [execution-id]

PIPELINE_NAME=${1:-${PIPELINE_NAME:-devops-refresher-app-pipeline}}
EXEC_ID=${2:-}

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

if [[ -z "$EXEC_ID" ]]; then
  EXEC_ID=$(aws_call codepipeline list-pipeline-executions \
    --pipeline-name "$PIPELINE_NAME" \
    --max-items 1 \
    --query 'pipelineExecutionSummaries[0].pipelineExecutionId' --output text)
fi

echo "Watching pipeline '$PIPELINE_NAME' execution '$EXEC_ID' (region: $REGION, profile: $PROFILE)" >&2

while true; do
  STATUS=$(aws_call codepipeline get-pipeline-execution \
    --pipeline-name "$PIPELINE_NAME" \
    --pipeline-execution-id "$EXEC_ID" \
    --query 'pipelineExecution.status' --output text)

  echo "Status: $STATUS" >&2

  case "$STATUS" in
    Succeeded)
      echo "Succeeded"
      exit 0
      ;;
    Failed|Superseded|Stopped)
      echo "Failed: $STATUS" >&2
      # Dump stage-level statuses for context
      aws_call codepipeline get-pipeline-execution \
        --pipeline-name "$PIPELINE_NAME" \
        --pipeline-execution-id "$EXEC_ID" \
        --query 'pipelineExecution.artifactRevisions[*].{name:name,rev:revisionId,url:revisionUrl}' \
        --output table || true
      exit 2
      ;;
  esac
  sleep 5
done

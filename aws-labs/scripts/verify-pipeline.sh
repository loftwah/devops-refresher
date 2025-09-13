#!/usr/bin/env bash
set -euo pipefail

# Verify a CodePipeline execution completes successfully.
# Usage examples:
#   ./verify-pipeline.sh <pipeline-name> [region]
#   EXEC_ID=$(./codepipeline-start.sh <pipeline>) && ./verify-pipeline.sh <pipeline> [region] "$EXEC_ID"
# Env vars: PIPELINE_NAME, AWS_REGION

PIPELINE_NAME=${1:-${PIPELINE_NAME:-devops-refresher-app-pipeline}}
REGION=${2:-${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-2}}}
EXEC_ID=${3:-}

if [[ -z "$PIPELINE_NAME" ]]; then
  echo "Error: PIPELINE_NAME is required" >&2
  exit 1
fi

if [[ -z "$EXEC_ID" ]]; then
  EXEC_ID=$(aws codepipeline list-pipeline-executions \
    --pipeline-name "$PIPELINE_NAME" \
    --region "$REGION" \
    --max-items 1 \
    --query 'pipelineExecutionSummaries[0].pipelineExecutionId' --output text)
fi

echo "Watching pipeline '$PIPELINE_NAME' execution '$EXEC_ID' (region: $REGION)" >&2

while true; do
  STATUS=$(aws codepipeline get-pipeline-execution \
    --pipeline-name "$PIPELINE_NAME" \
    --pipeline-execution-id "$EXEC_ID" \
    --region "$REGION" \
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
      aws codepipeline get-pipeline-execution \
        --pipeline-name "$PIPELINE_NAME" \
        --pipeline-execution-id "$EXEC_ID" \
        --region "$REGION" \
        --query 'pipelineExecution.artifactRevisions[*].{name:name,rev:revisionId,url:revisionUrl}' \
        --output table || true
      exit 2
      ;;
  esac
  sleep 5
done


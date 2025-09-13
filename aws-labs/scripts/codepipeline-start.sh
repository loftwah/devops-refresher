#!/usr/bin/env bash
set -euo pipefail

# Kick off a CodePipeline execution.
# Usage: PIPELINE_NAME=<name> AWS_REGION=<region> ./codepipeline-start.sh
# Or: ./codepipeline-start.sh <pipeline-name> [region]

PIPELINE_NAME=${1:-${PIPELINE_NAME:-devops-refresher-app-pipeline}}
REGION=${2:-${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-2}}}

if [[ -z "$PIPELINE_NAME" ]]; then
  echo "Error: PIPELINE_NAME is required" >&2
  exit 1
fi

echo "Starting pipeline: $PIPELINE_NAME (region: $REGION)" >&2
EXEC_ID=$(aws codepipeline start-pipeline-execution \
  --name "$PIPELINE_NAME" \
  --region "$REGION" \
  --query 'pipelineExecutionId' --output text)

echo "$EXEC_ID"


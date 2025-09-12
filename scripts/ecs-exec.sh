#!/usr/bin/env bash
set -Eeuo pipefail

# Minimal, opinionated ECS Exec helper for this repo.
# Hard-coded to staging environment values. No discovery, no prompts.

PROFILE="devops-sandbox"
REGION="ap-southeast-2"
CLUSTER="devops-refresher-staging"
SERVICE="app"
CONTAINER="app"

aws_cli() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

# Allow passing a specific task ID/ARN as the first arg; otherwise pick first RUNNING task for the service
TASK_INPUT="${1:-}"
if [[ -n "$TASK_INPUT" ]]; then
  TASK="$TASK_INPUT"
else
  TASK=$(aws_cli ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --desired-status RUNNING \
    --query 'taskArns[0]' --output text)
  if [[ -z "$TASK" || "$TASK" == "None" ]]; then
    echo "No RUNNING tasks for service '$SERVICE' in cluster '$CLUSTER'" >&2
    exit 1
  fi
fi

echo "Opening shell into $TASK container $CONTAINER"
if ! aws_cli ecs execute-command --cluster "$CLUSTER" --task "$TASK" --container "$CONTAINER" --interactive --command "/bin/sh"; then
  aws_cli ecs execute-command --cluster "$CLUSTER" --task "$TASK" --container "$CONTAINER" --interactive --command "/bin/bash" || true
fi


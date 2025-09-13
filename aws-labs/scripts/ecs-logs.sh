#!/usr/bin/env bash
set -Eeuo pipefail

# Tail logs for an ECS service's tasks.
# Usage: ecs-logs.sh --cluster <name> --service <name>

# Enforced lab context
PROFILE="devops-sandbox"
REGION="ap-southeast-2"

CLUSTER=""
SERVICE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 --cluster <name> --service <name>"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

[[ -n "$CLUSTER" && -n "$SERVICE" ]] || { echo "Missing --cluster/--service" >&2; exit 1; }

aws_cli() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

TASK_ARN=$(aws_cli ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --desired-status RUNNING --query 'taskArns[0]' --output text)
[[ "$TASK_ARN" != "None" && -n "$TASK_ARN" ]] || { echo "No running tasks" >&2; exit 1; }

LOG_GROUP=$(aws_cli ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[0].logConfiguration.options["awslogs-group"]' --output text)
LOG_STREAM_PREFIX=$(aws_cli ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[0].logConfiguration.options["awslogs-stream-prefix"]' --output text)

TASK_ID=$(basename "$TASK_ARN")
STREAM_NAME="$LOG_STREAM_PREFIX/$SERVICE/$TASK_ID"

echo "Tailing: $LOG_GROUP :: $STREAM_NAME (region: $REGION, profile: $PROFILE)"
aws_cli logs tail "$LOG_GROUP" --follow --log-stream-names "$STREAM_NAME"

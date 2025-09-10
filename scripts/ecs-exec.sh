#!/usr/bin/env bash
set -Eeuo pipefail

# Open a shell into an ECS task container using ECS Exec (SSM).
# Usage: ecs-exec.sh --cluster <name> --service <name> [--container <name>] [-p profile] [-r region]

PROFILE="${AWS_PROFILE:-}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
CLUSTER=""
SERVICE=""
CONTAINER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) CLUSTER="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    --container) CONTAINER="$2"; shift 2 ;;
    -p|--profile) PROFILE="$2"; shift 2 ;;
    -r|--region)  REGION="$2";  shift 2 ;;
    -h|--help) echo "Usage: $0 --cluster <name> --service <name> [--container <name>] [-p profile] [-r region]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

[[ -n "$CLUSTER" && -n "$SERVICE" ]] || { echo "Missing --cluster/--service"; exit 1; }

aws_cli() { aws ${PROFILE:+--profile "$PROFILE"} ${REGION:+--region "$REGION"} "$@"; }

TASK_ARN=$(aws_cli ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --desired-status RUNNING --query 'taskArns[0]' --output text)
[[ "$TASK_ARN" != "None" ]] || { echo "No running tasks"; exit 1; }

if [[ -z "$CONTAINER" ]]; then
  CONTAINER=$(aws_cli ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --query 'tasks[0].containers[0].name' --output text)
fi

echo "Opening shell into $TASK_ARN container $CONTAINER"
aws_cli ecs execute-command --cluster "$CLUSTER" --task "$TASK_ARN" --container "$CONTAINER" \
  --interactive --command "/bin/sh"


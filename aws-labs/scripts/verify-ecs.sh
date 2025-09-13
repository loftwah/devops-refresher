#!/usr/bin/env bash
set -Eeuo pipefail

# Verify ECS service rolled a new task and is stable; print current image.
# Usage: ./verify-ecs.sh [cluster_name] [service_name]

CLUSTER=${1:-${ECS_CLUSTER_NAME:-devops-refresher-staging}}
SERVICE=${2:-${ECS_SERVICE_NAME:-app}}

# Enforced lab context
PROFILE="devops-sandbox"
REGION="ap-southeast-2"

aws_call() {
  aws "$@" --profile "$PROFILE" --region "$REGION"
}

echo "Waiting for ECS service to be stable: $CLUSTER/$SERVICE (region: $REGION, profile: $PROFILE)" >&2

aws_call ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"

DESC=$(aws_call ecs describe-services --cluster "$CLUSTER" --services "$SERVICE")
TD_ARN=$(echo "$DESC" | jq -r '.services[0].taskDefinition')
RUNNING=$(echo "$DESC" | jq -r '.services[0].runningCount')
DESIRED=$(echo "$DESC" | jq -r '.services[0].desiredCount')

TD=$(aws_call ecs describe-task-definition --task-definition "$TD_ARN")
IMAGE=$(echo "$TD" | jq -r '.taskDefinition.containerDefinitions[0].image')
CONTAINER=$(echo "$TD" | jq -r '.taskDefinition.containerDefinitions[0].name')

echo "Service stable. Desired=$DESIRED Running=$RUNNING"
echo "TaskDefinition: $TD_ARN"
echo "Container: $CONTAINER"
echo "Image: $IMAGE"

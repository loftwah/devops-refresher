#!/usr/bin/env bash
set -euo pipefail

# Verify ECS service rolled a new task and is stable; print current image.
# Usage: ./verify-ecs.sh [cluster_name] [service_name] [region]
# Defaults: cluster=devops-refresher-staging, service=app, region from env or ap-southeast-2

CLUSTER=${1:-${ECS_CLUSTER_NAME:-devops-refresher-staging}}
SERVICE=${2:-${ECS_SERVICE_NAME:-app}}
REGION=${3:-${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-2}}}

echo "Waiting for ECS service to be stable: $CLUSTER/$SERVICE (region: $REGION)" >&2
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION"

DESC=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION")
TD_ARN=$(echo "$DESC" | jq -r '.services[0].taskDefinition')
RUNNING=$(echo "$DESC" | jq -r '.services[0].runningCount')
DESIRED=$(echo "$DESC" | jq -r '.services[0].desiredCount')

TD=$(aws ecs describe-task-definition --task-definition "$TD_ARN" --region "$REGION")
IMAGE=$(echo "$TD" | jq -r '.taskDefinition.containerDefinitions[0].image')
CONTAINER=$(echo "$TD" | jq -r '.taskDefinition.containerDefinitions[0].name')

echo "Service stable. Desired=$DESIRED Running=$RUNNING"
echo "TaskDefinition: $TD_ARN"
echo "Container: $CONTAINER"
echo "Image: $IMAGE"


#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="devops-sandbox"
REGION="ap-southeast-2"
CLUSTER="devops-refresher-staging"
SERVICE="app"
WAIT=false

if [[ "${1:-}" == "--wait" ]]; then WAIT=true; shift; fi

aws --profile "$PROFILE" --region "$REGION" ecs update-service \
  --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment >/dev/null

if [[ "$WAIT" == true ]]; then
  aws --profile "$PROFILE" --region "$REGION" ecs wait services-stable \
    --cluster "$CLUSTER" --services "$SERVICE"
  echo "Redeploy completed and service is stable for $SERVICE in $CLUSTER ($REGION)"
else
  echo "Redeploy triggered for $SERVICE in $CLUSTER ($REGION)"
fi



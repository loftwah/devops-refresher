#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="devops-sandbox"
REGION="ap-southeast-2"
CLUSTER="devops-refresher-staging"
SERVICE="app"

aws --profile "$PROFILE" --region "$REGION" ecs update-service \
  --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment >/dev/null

aws --profile "$PROFILE" --region "$REGION" ecs wait services-stable \
  --cluster "$CLUSTER" --services "$SERVICE"

echo "Redeploy completed for $SERVICE in $CLUSTER ($REGION)"



#!/usr/bin/env bash
set -euo pipefail

# Verify app health via HTTP /healthz. Provide the base URL (ALB or DNS name).
# Usage: ./verify-app-health.sh <http(s)://host[:port]>

BASE_URL=${1:-}

if [[ -z "$BASE_URL" ]]; then
  echo "Usage: $0 <http(s)://host[:port]>" >&2
  exit 1
fi

URL="$BASE_URL/healthz"
echo "Checking $URL" >&2

CODE=$(curl -sS -o /dev/null -w "%{http_code}" "$URL")
if [[ "$CODE" == "200" ]]; then
  echo "Healthy: $URL => 200"
  exit 0
else
  echo "Unhealthy: $URL => $CODE" >&2
  exit 2
fi


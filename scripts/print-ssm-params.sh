#!/usr/bin/env bash
set -euo pipefail

# Print AWS SSM Parameter Store values under a path.
# Usage: print-ssm-params.sh [SSM_PATH] [AWS_REGION]
# If SSM_PATH is omitted, attempts:
#  1) $SSM_PATH env var
#  2) `terraform output -raw ssm_path_prefix` in CWD
#  3) Fallback to /devops-refresher/staging/app

PARAM_PATH=${1:-${SSM_PATH:-}}
AWS_REGION_CLI=${2:-${AWS_REGION:-${AWS_DEFAULT_REGION:-}}}
AWS_PROFILE_CLI=${AWS_PROFILE:-}

# Validate SSM path matches allowed pattern (leading /, allowed chars)
valid_path() {
  [[ "$1" =~ ^/[A-Za-z0-9._\-/]+$ ]]
}

# Resolve PARAM_PATH if omitted
if [[ -z "$PARAM_PATH" ]]; then
  if command -v terraform >/dev/null 2>&1; then
    if PARAM_TF_OUT=$(terraform output -raw ssm_path_prefix 2>/dev/null); then
      # Trim whitespace
      PARAM_TF_OUT="${PARAM_TF_OUT//$'\n'/}"
      PARAM_TF_OUT="${PARAM_TF_OUT//$'\r'/}"
      if valid_path "$PARAM_TF_OUT"; then
        PARAM_PATH="$PARAM_TF_OUT"
        echo "[ssm-dump] Using Terraform output ssm_path_prefix: $PARAM_PATH" >&2
      fi
    fi
  fi
fi

# Final fallback
if [[ -z "$PARAM_PATH" ]]; then
  PARAM_PATH="/devops-refresher/staging/app"
  echo "[ssm-dump] No path provided; defaulting to $PARAM_PATH" >&2
fi

AWS_ARGS=()
# Profile: use current env if set, else project default
if [[ -n "$AWS_PROFILE_CLI" ]]; then
  AWS_ARGS+=("--profile" "$AWS_PROFILE_CLI")
else
  AWS_ARGS+=("--profile" "devops-sandbox")
fi
# Region: use arg/env if set, else project default
if [[ -n "$AWS_REGION_CLI" ]]; then
  AWS_ARGS+=("--region" "$AWS_REGION_CLI")
else
  AWS_ARGS+=("--region" "ap-southeast-2")
fi

echo "[ssm-dump] Path: $PARAM_PATH" >&2

echo
echo "== Table =="
# Pretty table of Name and Value
# shellcheck disable=SC2145
# First, check if any parameters exist; if not, exit 0 with a note
COUNT=$(aws ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --with-decryption \
  --recursive \
  --query 'length(Parameters)' \
  --output text ${AWS_ARGS[@]:-} 2>/dev/null || echo 0)
if [[ "$COUNT" == "0" || -z "$COUNT" || "$COUNT" == "None" ]]; then
  echo "(no parameters found under $PARAM_PATH)" 
  exit 0
fi

aws ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --with-decryption \
  --recursive \
  --query 'Parameters[].{Name:Name,Value:Value}' \
  --output table ${AWS_ARGS[@]:-}

echo
echo "== KEY=VALUE =="
# KEY=VALUE using the last path segment for KEY
# Use text output (tab-separated) then format with awk
# shellcheck disable=SC2145
aws ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --with-decryption \
  --recursive \
  --query 'Parameters[].{Name:Name,Value:Value}' \
  --output text ${AWS_ARGS[@]:-} | \
awk '{name=$1; $1=""; sub(/^ /,""); split(name,parts,"/"); key=parts[length(parts)]; print key"="$0}'

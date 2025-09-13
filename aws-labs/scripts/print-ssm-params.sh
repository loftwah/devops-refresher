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
echo "== Table (SSM) =="
# Pretty table of Name and Value from SSM (non-secrets)
# shellcheck disable=SC2145
SSM_COUNT=$(aws ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --with-decryption \
  --recursive \
  --query 'length(Parameters)' \
  --output text ${AWS_ARGS[@]:-} 2>/dev/null || echo 0)
if [[ "$SSM_COUNT" == "0" || -z "$SSM_COUNT" || "$SSM_COUNT" == "None" ]]; then
  echo "(no SSM parameters found under $PARAM_PATH)"
else
  aws ssm get-parameters-by-path \
    --path "$PARAM_PATH" \
    --with-decryption \
    --recursive \
    --query 'Parameters[].{Name:Name,Value:Value}' \
    --output table ${AWS_ARGS[@]:-}
fi

echo
echo "== KEY=VALUE (SSM + Secrets) =="
# SSM: KEY=VALUE using the last path segment for KEY
# shellcheck disable=SC2145
if [[ "$SSM_COUNT" != "0" && -n "$SSM_COUNT" && "$SSM_COUNT" != "None" ]]; then
  aws ssm get-parameters-by-path \
    --path "$PARAM_PATH" \
    --with-decryption \
    --recursive \
    --query 'Parameters[].{Name:Name,Value:Value}' \
    --output text ${AWS_ARGS[@]:-} | \
  awk '{name=$1; $1=""; sub(/^ /,""); split(name,parts,"/"); key=parts[length(parts)]; print key"="$0}'
fi

# Secrets Manager: include DB_PASS and others under the same prefix
# Show real values by default; set MASK_SECRETS=1 to mask
SECRETS_NAMES=$(aws secretsmanager list-secrets \
  --filters Key=name,Values="$PARAM_PATH/" \
  --query 'SecretList[].Name' \
  --output text ${AWS_ARGS[@]:-} 2>/dev/null | tr '\t' '\n' | grep -E "^${PARAM_PATH}/" || true)
if [[ -z "$SECRETS_NAMES" ]]; then
  :
else
  while IFS= read -r sec; do
    key=${sec##*/}
    if [[ "${MASK_SECRETS:-0}" == "1" || "${MASK_SECRETS:-false}" == "true" ]]; then
      printf "%s=%s\n" "$key" "******"
    else
      val=$(aws secretsmanager get-secret-value --secret-id "$sec" --query SecretString --output text ${AWS_ARGS[@]:-} 2>/dev/null || echo "")
      printf "%s=%s\n" "$key" "$val"
    fi
  done <<< "$SECRETS_NAMES"
fi

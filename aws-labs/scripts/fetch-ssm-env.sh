#!/usr/bin/env bash
set -euo pipefail

# Usage: fetch-ssm-env.sh [SSM_PATH]
# Exports SSM parameters under the given path as environment variables.
# Resolution order for SSM_PATH when omitted:
#   1) $SSM_PATH env var
#   2) `terraform output -raw ssm_path_prefix` in CWD
#   3) /devops-refresher/staging/app

PARAM_PATH=${1:-${SSM_PATH:-}}
PROFILE="devops-sandbox"
REGION="ap-southeast-2"

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
        echo "[fetch-ssm-env] Using Terraform output ssm_path_prefix: $PARAM_PATH" >&2
      fi
    fi
  fi
fi

# Final fallback
if [[ -z "$PARAM_PATH" ]]; then
  PARAM_PATH="/devops-refresher/staging/app"
  echo "[fetch-ssm-env] No path provided; defaulting to $PARAM_PATH" >&2
fi

aws_cli() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

# Check if any parameters exist first; if none, exit 0 quietly
COUNT=$(aws_cli ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --with-decryption \
  --recursive \
  --query 'length(Parameters)' \
  --output text 2>/dev/null || echo 0)
if [[ "$COUNT" == "0" || -z "$COUNT" || "$COUNT" == "None" ]]; then
  echo "[fetch-ssm-env] No parameters found under $PARAM_PATH" >&2
  return 0 2>/dev/null || exit 0
fi

# Fetch parameters and export them as env vars
while IFS=$'\t' read -r name value; do
  key=${name##*/}
  # shellcheck disable=SC2086
  export "$key"="$value"
done < <(
  aws_cli ssm get-parameters-by-path \
    --path "$PARAM_PATH" \
    --with-decryption \
    --recursive \
    --query 'Parameters[*].{Name:Name,Value:Value}' \
    --output text | awk '{print $1"\t"$2}'
)

# Export secrets under the same prefix (e.g., DB_PASS)
SECRETS_NAMES=$(aws_cli secretsmanager list-secrets \
  --filters Key=name,Values="$PARAM_PATH/" \
  --query 'SecretList[].Name' \
  --output text 2>/dev/null | tr '\t' '\n' | grep -E "^${PARAM_PATH}/" || true)
if [[ -n "$SECRETS_NAMES" ]]; then
  while IFS= read -r sec; do
    key=${sec##*/}
    val=$(aws_cli secretsmanager get-secret-value --secret-id "$sec" --query SecretString --output text 2>/dev/null || echo "")
    export "$key"="$val"
  done <<< "$SECRETS_NAMES"
fi

# Print exported keys for visibility (mark secrets)
echo "[fetch-ssm-env] Exported keys from $PARAM_PATH:" >&2
aws_cli ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --query 'Parameters[*].Name' \
  --output text | tr '\t' '\n' | sed 's#.*/##' >&2
if [[ -n "$SECRETS_NAMES" ]]; then
  while IFS= read -r sec; do
    echo "${sec##*/} (secret)" >&2
  done <<< "$SECRETS_NAMES"
fi

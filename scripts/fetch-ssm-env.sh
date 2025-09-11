#!/usr/bin/env bash
set -euo pipefail

# Usage: fetch-ssm-env.sh /devops-refresher/staging/app [AWS_REGION]
# Exports SSM parameters under the given path as environment variables.
# - Non-secret String and SecureString values are supported (requires IAM perms).
# - Keys are derived from the last path segment.

PARAM_PATH=${1:-}
AWS_REGION=${2:-${AWS_REGION:-}}

if [[ -z "$PARAM_PATH" ]]; then
  echo "Usage: $0 <ssm-parameter-path> [region]" >&2
  exit 1
fi

AWS_ARGS=()
if [[ -n "$AWS_REGION" ]]; then
  AWS_ARGS+=("--region" "$AWS_REGION")
fi

# Fetch parameters and export them as env vars
while IFS=$'\t' read -r name value; do
  key=${name##*/}
  # shellcheck disable=SC2086
  export "$key"="$value"
done < <(
  aws ssm get-parameters-by-path \
    --path "$PARAM_PATH" \
    --with-decryption \
    --query 'Parameters[*].{Name:Name,Value:Value}' \
    --output text ${AWS_ARGS[@]:-} | awk '{print $1"\t"$2}'
)

# Print exported keys for visibility
echo "[fetch-ssm-env] Exported keys from $PARAM_PATH:" >&2
aws ssm get-parameters-by-path \
  --path "$PARAM_PATH" \
  --query 'Parameters[*].Name' \
  --output text ${AWS_ARGS[@]:-} | tr '\t' '\n' | sed 's#.*/##' >&2


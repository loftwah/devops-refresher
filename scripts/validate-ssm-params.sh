#!/usr/bin/env bash
set -Eeuo pipefail

# Validates SSM Parameter Store and Secrets for aws-labs/11-parameter-store
# - Ensures required SSM params exist under /devops-refresher/<env>/<service>
# - Optionally checks DB_PASS secret exists

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
SSM_DIR="$ROOT_DIR/aws-labs/11-parameter-store"

# Basic colored output (respects NO_COLOR and non-TTY)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

AWS_PROFILE_EFFECTIVE="${AWS_PROFILE:-}"
AWS_REGION_EFFECTIVE="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
ENV_NAME="staging"
SERVICE_NAME="app"

REQUIRED_KEYS=(
  APP_ENV LOG_LEVEL PORT S3_BUCKET
  DB_HOST DB_PORT DB_USER DB_NAME DB_SSL
  REDIS_HOST REDIS_PORT SELF_TEST_ON_BOOT
)

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--profile) AWS_PROFILE_EFFECTIVE="$2"; shift 2 ;;
      -r|--region)  AWS_REGION_EFFECTIVE="$2";  shift 2 ;;
      -e|--env)     ENV_NAME="$2";              shift 2 ;;
      -s|--service) SERVICE_NAME="$2";          shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  -p, --profile NAME   AWS profile
  -r, --region  NAME   AWS region
  -e, --env     NAME   Environment (default: $ENV_NAME)
  -s, --service NAME   Service (default: $SERVICE_NAME)
EOF
        exit 0 ;;
      *) err "Unknown argument: $1"; exit 2 ;;
    esac
  done
}

aws_cli() {
  local region_flag=( ) profile_flag=( )
  [[ -n "${AWS_REGION_EFFECTIVE:-}" ]] && region_flag=(--region "$AWS_REGION_EFFECTIVE")
  [[ -n "${AWS_PROFILE_EFFECTIVE:-}" ]] && profile_flag=(--profile "$AWS_PROFILE_EFFECTIVE")
  aws "${profile_flag[@]}" "${region_flag[@]}" "$@"
}

discover_defaults() {
  if [[ -z "${AWS_PROFILE_EFFECTIVE:-}" && -f "$SSM_DIR/providers.tf" ]]; then
    AWS_PROFILE_EFFECTIVE=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$SSM_DIR/providers.tf" || true)
  fi
  if [[ -z "${AWS_REGION_EFFECTIVE:-}" && -f "$SSM_DIR/providers.tf" ]]; then
    AWS_REGION_EFFECTIVE=$(awk '/variable "region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$SSM_DIR/providers.tf" || true)
  fi
  # Try to infer env/service from Terraform output ssm_path_prefix
  if command -v terraform >/dev/null 2>&1; then
    if terraform -chdir="$SSM_DIR" init -input=false >/dev/null 2>&1; then
      local tf_json prefix
      tf_json=$(terraform -chdir="$SSM_DIR" output -json 2>/dev/null || echo '{}')
      prefix=$(jq -r '.ssm_path_prefix.value' <<<"$tf_json" 2>/dev/null || echo "")
      # Expect /devops-refresher/<env>/<service>
      if [[ "$prefix" =~ ^/devops-refresher/([^/]+)/([^/]+)$ ]]; then
        ENV_NAME="${BASH_REMATCH[1]}"
        SERVICE_NAME="${BASH_REMATCH[2]}"
      fi
    fi
  fi
  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"
  info "Using prefix /devops-refresher/${ENV_NAME}/${SERVICE_NAME}"
}

check_params() {
  local prefix="/devops-refresher/${ENV_NAME}/${SERVICE_NAME}"
  info "Checking SSM parameters under: $prefix"
  local names_json
  names_json=$(aws_cli ssm get-parameters-by-path --path "$prefix" --with-decryption --query 'Parameters[].Name' --output json)
  for key in "${REQUIRED_KEYS[@]}"; do
    local want="$prefix/$key"
    if jq -e --arg n "$want" '.[]|select(.==$n)' <<<"$names_json" >/dev/null; then
      ok "Param exists: $want"
    else
      err "Missing param: $want"; exit 1
    fi
  done
}

check_db_secret() {
  local secret_name="/devops-refresher/${ENV_NAME}/${SERVICE_NAME}/DB_PASS"
  local arn
  arn=$(aws_cli secretsmanager list-secrets --query 'SecretList[].Name' --output text | tr '\t' '\n' | grep -x "$secret_name" || true)
  if [[ -n "$arn" ]]; then
    ok "DB_PASS secret exists: $secret_name"
  else
    info "DB_PASS secret not found in Secrets Manager (created in RDS lab)."
  fi
}

check_app_auth_secret() {
  local secret_name="/devops-refresher/${ENV_NAME}/${SERVICE_NAME}/APP_AUTH_SECRET"
  local arn
  arn=$(aws_cli secretsmanager list-secrets --query 'SecretList[].Name' --output text | tr '\t' '\n' | grep -x "$secret_name" || true)
  if [[ -n "$arn" ]]; then
    ok "APP_AUTH_SECRET exists: $secret_name"
  else
    err "APP_AUTH_SECRET not found in Secrets Manager. It should be auto-created by the Parameter Store lab when applied."
    exit 1
  fi
}

main() {
  require aws; require jq
  parse_args "$@"
  discover_defaults
  check_params
  check_db_secret
  check_app_auth_secret
  ok "Parameter Store validation passed"
}

main "$@"

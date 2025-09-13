#!/usr/bin/env bash
set -Eeuo pipefail

# Validates RDS instance from aws-labs/09-rds
# - Reads DB outputs (host/port/user/name) and rds_sg_id from Terraform
# - Checks DB instance exists/available and not public
# - Verifies SG allows 5432 from app SG (discovered from Lab 07)

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
RDS_DIR="$ROOT_DIR/09-rds"
SG_DIR="$ROOT_DIR/07-security-groups"

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

PROFILE="devops-sandbox"
REGION="ap-southeast-2"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      # Profile/region are enforced by this lab; flags intentionally not supported
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  (Profile/region are enforced by this lab: devops-sandbox / ap-southeast-2)
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
  if [[ -z "${AWS_PROFILE_EFFECTIVE:-}" && -f "$RDS_DIR/providers.tf" ]]; then
    AWS_PROFILE_EFFECTIVE=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$RDS_DIR/providers.tf" || true)
  fi
  if [[ -z "${AWS_REGION_EFFECTIVE:-}" && -f "$RDS_DIR/providers.tf" ]]; then
    AWS_REGION_EFFECTIVE=$(awk '/variable "region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$RDS_DIR/providers.tf" || true)
  fi
  [[ -n "${AWS_PROFILE_EFFECTIVE:-}" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "${AWS_REGION_EFFECTIVE:-}"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"
}

read_tf_outputs() {
  require terraform; require jq
  terraform -chdir="$RDS_DIR" init -input=false >/dev/null
  local tf_json
  tf_json=$(terraform -chdir="$RDS_DIR" output -json)
  DB_HOST=$(jq -r '.db_host.value' <<<"$tf_json")
  DB_PORT=$(jq -r '.db_port.value' <<<"$tf_json")
  DB_NAME=$(jq -r '.db_name.value' <<<"$tf_json")
  DB_USER=$(jq -r '.db_user.value' <<<"$tf_json")
  RDS_SG_ID=$(jq -r '.rds_sg_id.value' <<<"$tf_json")
  [[ -n "$DB_HOST" && "$DB_HOST" != "null" ]] || { err "Missing db_host output"; exit 1; }
  info "Outputs: host=$DB_HOST port=$DB_PORT name=$DB_NAME user=$DB_USER sg=$RDS_SG_ID"

  terraform -chdir="$SG_DIR" init -input=false >/dev/null || true
  local sg_json
  sg_json=$(terraform -chdir="$SG_DIR" output -json 2>/dev/null || echo '{}')
  APP_SG_ID=$(jq -r '.app_sg_id.value' <<<"$sg_json" 2>/dev/null || echo "")
}

check_instance() {
  local db_id state pub
  read -r db_id state pub < <(aws_cli rds describe-db-instances \
    --query "DBInstances[?Endpoint.Address=='$DB_HOST'].[DBInstanceIdentifier,DBInstanceStatus,PubliclyAccessible]" \
    --output text)
  [[ -n "$db_id" ]] || { err "RDS instance not found for endpoint $DB_HOST"; exit 1; }
  [[ "$state" == "available" ]] || { err "RDS state not 'available' (got: $state)"; exit 1; }
  [[ "$pub" == "False" ]] || { err "RDS instance is public (expected private)"; exit 1; }
  ok "RDS instance $db_id is available and private"
}

check_sg_rules() {
  [[ -n "${RDS_SG_ID:-}" ]] || { info "rds_sg_id output missing; skipping SG rule check"; return; }
  local desc ingress
  desc=$(aws_cli ec2 describe-security-groups --group-ids "$RDS_SG_ID")
  if [[ -n "${APP_SG_ID:-}" ]]; then
    ingress=$(jq -r --arg APP "$APP_SG_ID" '.SecurityGroups[0].IpPermissions[]?|select(.FromPort==5432 and .ToPort==5432 and .IpProtocol=="tcp")|select(.UserIdGroupPairs[]?.GroupId==$APP)' <<<"$desc" || true)
    [[ -n "$ingress" ]] || { err "RDS SG missing 5432 ingress from app SG $APP_SG_ID"; exit 1; }
    ok "RDS SG allows 5432 from app SG $APP_SG_ID"
  else
    info "App SG not found in outputs; ensure inbound 5432 is restricted to app SG"
  fi
}

main() {
  require aws; require jq
  parse_args "$@"
  discover_defaults
  read_tf_outputs
  check_instance
  check_sg_rules
  ok "RDS validation passed"
}

main "$@"

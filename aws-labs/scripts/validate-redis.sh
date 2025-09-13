#!/usr/bin/env bash
set -Eeuo pipefail

# Validates Redis (ElastiCache) from aws-labs/10-elasticache-redis
# - Reads outputs: redis_host, redis_port, redis_sg_id
# - Checks replication group exists, encryption at rest/transit enabled
# - Verifies SG allows 6379 from app SG (from Lab 07)

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
REDIS_DIR="$ROOT_DIR/10-elasticache-redis"
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

AWS_PROFILE_EFFECTIVE="${AWS_PROFILE:-}"
AWS_REGION_EFFECTIVE="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--profile) AWS_PROFILE_EFFECTIVE="$2"; shift 2 ;;
      -r|--region)  AWS_REGION_EFFECTIVE="$2";  shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  -p, --profile NAME   AWS profile
  -r, --region  NAME   AWS region
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
  if [[ -z "${AWS_PROFILE_EFFECTIVE:-}" && -f "$REDIS_DIR/providers.tf" ]]; then
    AWS_PROFILE_EFFECTIVE=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$REDIS_DIR/providers.tf" || true)
  fi
  if [[ -z "${AWS_REGION_EFFECTIVE:-}" && -f "$REDIS_DIR/providers.tf" ]]; then
    AWS_REGION_EFFECTIVE=$(awk '/variable "region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$REDIS_DIR/providers.tf" || true)
  fi
  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"
}

read_tf_outputs() {
  require terraform; require jq
  terraform -chdir="$REDIS_DIR" init -input=false >/dev/null
  local tf_json
  tf_json=$(terraform -chdir="$REDIS_DIR" output -json)
  REDIS_HOST=$(jq -r '.redis_host.value' <<<"$tf_json")
  REDIS_PORT=$(jq -r '.redis_port.value' <<<"$tf_json")
  REDIS_SG_ID=$(jq -r '.redis_sg_id.value' <<<"$tf_json")
  [[ -n "$REDIS_HOST" && "$REDIS_HOST" != "null" ]] || { err "Missing redis_host output"; exit 1; }
  info "Outputs: host=$REDIS_HOST port=$REDIS_PORT sg=$REDIS_SG_ID"

  terraform -chdir="$SG_DIR" init -input=false >/dev/null || true
  local sg_json
  sg_json=$(terraform -chdir="$SG_DIR" output -json 2>/dev/null || echo '{}')
  APP_SG_ID=$(jq -r '.app_sg_id.value' <<<"$sg_json" 2>/dev/null || echo "")
}

check_replication_group() {
  # Derive replication group by looking up cache cluster by primary endpoint
  local rg_json
  rg_json=$(aws_cli elasticache describe-replication-groups --query 'ReplicationGroups' --output json)
  # Find the group that matches the primary endpoint
  local found
  # Build a TSV line as an array to satisfy jq's @tsv requirement
  # Be tolerant of shapes: iterate NodeGroups and guard missing fields with ?
  found=$(jq -r --arg host "$REDIS_HOST" '
      .[]
      | select( any(.NodeGroups[]?; .PrimaryEndpoint?.Address == $host) )
      | [.ReplicationGroupId, .AtRestEncryptionEnabled, .TransitEncryptionEnabled]
      | @tsv
    ' <<<"$rg_json" || true)
  [[ -n "$found" ]] || { err "Redis replication group not found for endpoint $REDIS_HOST"; exit 1; }
  local rg_id at_rest transit
  rg_id=$(cut -f1 <<<"$found"); at_rest=$(cut -f2 <<<"$found"); transit=$(cut -f3 <<<"$found")
  [[ "$at_rest" == "true" ]]  || { err "At-rest encryption not enabled on $rg_id"; exit 1; }
  [[ "$transit" == "true" ]]  || { err "Transit encryption not enabled on $rg_id"; exit 1; }
  ok "Redis group $rg_id has encryption at-rest and in-transit"
}

check_sg_rules() {
  [[ -n "${REDIS_SG_ID:-}" ]] || { info "redis_sg_id output missing; skipping SG rule check"; return; }
  local desc ingress
  desc=$(aws_cli ec2 describe-security-groups --group-ids "$REDIS_SG_ID")
  if [[ -n "${APP_SG_ID:-}" ]]; then
    ingress=$(jq -r --arg APP "$APP_SG_ID" '.SecurityGroups[0].IpPermissions[]?|select(.FromPort==6379 and .ToPort==6379 and .IpProtocol=="tcp")|select(.UserIdGroupPairs[]?.GroupId==$APP)' <<<"$desc" || true)
    [[ -n "$ingress" ]] || { err "Redis SG missing 6379 ingress from app SG $APP_SG_ID"; exit 1; }
    ok "Redis SG allows 6379 from app SG $APP_SG_ID"
  else
    info "App SG not found in outputs; ensure inbound 6379 is restricted to app SG"
  fi
}

main() {
  require aws; require jq
  parse_args "$@"
  discover_defaults
  read_tf_outputs
  check_replication_group
  check_sg_rules
  ok "Redis validation passed"
}

main "$@"

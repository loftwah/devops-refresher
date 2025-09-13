#!/usr/bin/env bash
set -Eeuo pipefail

# Validates Observability lab (aws-labs/16-observability)
# - Confirms CloudWatch Dashboard exists
# - Confirms SNS topic + email subscription
# - Confirms key CloudWatch Alarms exist (ECS, ALB, RDS, Redis)
# - Confirms CloudWatch Logs metric filter for ERROR exists

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
OBS_DIR="$ROOT_DIR/aws-labs/16-observability"

# Colors (respect NO_COLOR and non-TTY)
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
      -h|--help)
        cat <<EOF
Usage: $(basename "$0")
  (Profile/region derived from 16-observability/providers.tf)
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
  if [[ -z "${AWS_PROFILE_EFFECTIVE:-}" && -f "$OBS_DIR/providers.tf" ]]; then
    AWS_PROFILE_EFFECTIVE=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$OBS_DIR/providers.tf" || true)
  fi
  if [[ -z "${AWS_REGION_EFFECTIVE:-}" && -f "$OBS_DIR/providers.tf" ]]; then
    AWS_REGION_EFFECTIVE=$(awk '/variable "region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$OBS_DIR/providers.tf" || true)
  fi
  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"
}

set_expected_names() {
  ENV="staging"
  SERVICE="app"
  CLUSTER="devops-refresher-staging"
  LOG_GROUP="/aws/ecs/devops-refresher-staging"
  DASHBOARD="devops-refresher-${ENV}"
  SNS_TOPIC_NAME="devops-refresher-${ENV}-alerts"
  ALERT_EMAIL="dean+aws@deanlofts.xyz"
  # Alarm names (must match Terraform)
  EXPECTED_ALARMS=(
    "${ENV}-alb-elb-5xx"
    "${ENV}-alb-target-5xx"
    "${ENV}-alb-latency-p95"
    "${ENV}-tg-unhealthy-hosts"
    "${ENV}-${SERVICE}-ecs-cpu-high"
    "${ENV}-${SERVICE}-ecs-memory-high"
    "${ENV}-${SERVICE}-ecs-log-errors"
    "${ENV}-${SERVICE}-postgres-cpu-high"
    "${ENV}-${SERVICE}-postgres-free-storage-low"
    "${ENV}-${SERVICE}-postgres-freeable-memory-low"
    "${ENV}-${SERVICE}-redis-cpu-high"
    "${ENV}-${SERVICE}-redis-evictions"
  )
}

check_dashboard() {
  require jq
  local resp
  resp=$(aws_cli cloudwatch get-dashboard --dashboard-name "$DASHBOARD" 2>/dev/null || true)
  local arn
  arn=$(jq -r '.DashboardArn // empty' <<<"$resp" || true)
  [[ -n "$arn" ]] || { err "Dashboard $DASHBOARD not found"; exit 1; }
  ok "Dashboard exists: $DASHBOARD"
}

check_sns() {
  require jq
  local topics arn
  topics=$(aws_cli sns list-topics --query 'Topics[].TopicArn' --output text)
  arn=$(awk -v name=":$SNS_TOPIC_NAME" '{ for(i=1;i<=NF;i++){ if(index($i,name)){ print $i } } }' <<<"$topics" | head -n1)
  [[ -n "$arn" ]] || { err "SNS topic $SNS_TOPIC_NAME not found"; exit 1; }
  ok "SNS topic exists: $SNS_TOPIC_NAME"

  local subs
  subs=$(aws_cli sns list-subscriptions-by-topic --topic-arn "$arn" --query 'Subscriptions[?Protocol==`email`].[Endpoint,SubscriptionArn]' --output text || true)
  if grep -q "$ALERT_EMAIL" <<<"$subs"; then
    if grep -q "$ALERT_EMAIL" <<<"$subs" | grep -vq "PendingConfirmation"; then
      ok "SNS email subscription present: $ALERT_EMAIL"
    else
      info "SNS email subscription pending confirmation for: $ALERT_EMAIL"
    fi
  else
    err "SNS email subscription not found for: $ALERT_EMAIL"; exit 1
  fi
}

check_log_metric_filter() {
  local name="${ENV}-${SERVICE}-ecs-error-filter"
  local resp
  resp=$(aws_cli logs describe-metric-filters --log-group-name "$LOG_GROUP" --filter-name-prefix "$name" --query 'metricFilters[0].filterPattern' --output text 2>/dev/null || true)
  [[ "$resp" != "None" && -n "$resp" ]] || { err "Log metric filter missing: $name on $LOG_GROUP"; exit 1; }
  [[ "$resp" == *ERROR* ]] || { err "Log metric filter pattern unexpected: $resp"; exit 1; }
  ok "Log metric filter exists on $LOG_GROUP: $name"
}

check_alarms_exist() {
  local missing=()
  for a in "${EXPECTED_ALARMS[@]}"; do
    local found
    found=$(aws_cli cloudwatch describe-alarms --alarm-names "$a" --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null || true)
    if [[ -z "$found" || "$found" == "None" ]]; then
      missing+=("$a")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    err "Missing alarms: ${missing[*]}"; exit 1
  fi
  ok "All expected alarms exist (${#EXPECTED_ALARMS[@]})"
}

main() {
  require aws
  parse_args "$@"
  discover_defaults
  set_expected_names
  check_dashboard
  check_sns
  check_log_metric_filter
  check_alarms_exist
  ok "Observability validation passed"
}

main "$@"


#!/usr/bin/env bash
set -Eeuo pipefail

# Validates ALB + ECS service end-to-end
# - HTTP 80 redirects to HTTPS
# - HTTPS /healthz returns 200
# - Target group has healthy targets
# - ECS service has running tasks

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
ALB_DIR="$ROOT_DIR/aws-labs/12-alb"
CLUSTER_DIR="$ROOT_DIR/aws-labs/13-ecs-cluster"

DOMAIN_FQDN="demo-node-app-ecs.aws.deanlofts.xyz"
CLUSTER_NAME=""
SERVICE_NAME="app"

# Basic colored output
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--domain)  DOMAIN_FQDN="$2"; shift 2 ;;
      --cluster)    CLUSTER_NAME="$2"; shift 2 ;;
      --service)    SERVICE_NAME="$2"; shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  -d, --domain FQDN  App domain (default: $DOMAIN_FQDN)
      --cluster NAME ECS cluster name (auto if omitted)
      --service NAME ECS service name (default: $SERVICE_NAME)
EOF
        exit 0 ;;
      *) err "Unknown argument: $1"; exit 2 ;;
    esac
  done
}

discover_cluster() {
  terraform -chdir="$CLUSTER_DIR" init -input=false >/dev/null
  if [[ -z "$CLUSTER_NAME" ]]; then
    CLUSTER_NAME=$(terraform -chdir="$CLUSTER_DIR" output -raw cluster_name)
  fi
  info "Using cluster: $CLUSTER_NAME, service: $SERVICE_NAME"
}

check_http_redirect() {
  require curl
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' "http://${DOMAIN_FQDN}/healthz")
  [[ "$code" == "301" || "$code" == "308" ]] || { err "HTTP did not redirect to HTTPS (got $code)"; exit 1; }
  ok "HTTP redirects to HTTPS"
}

check_https_health() {
  local code body
  code=$(curl -sS -o /tmp/healthz.body -w '%{http_code}' "https://${DOMAIN_FQDN}/healthz")
  [[ "$code" == "200" ]] || { err "HTTPS /healthz not 200 (got $code)"; exit 1; }
  ok "HTTPS /healthz returned 200"
}

check_tg_health() {
  require aws
  terraform -chdir="$ALB_DIR" init -input=false >/dev/null
  local TG
  TG=$(terraform -chdir="$ALB_DIR" output -raw tg_arn)
  local count
  count=$(aws elbv2 describe-target-health --target-group-arn "$TG" \
            --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' \
            --output json | jq 'length')
  [[ "$count" -ge 1 ]] || { err "Target group has no healthy targets"; exit 1; }
  ok "Target group has $count healthy target(s)"
}

check_ecs_service() {
  require aws
  local running desired
  running=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" \
              --query 'services[0].runningCount' --output text)
  desired=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" \
              --query 'services[0].desiredCount' --output text)
  [[ "$running" != "None" && "$running" -ge 1 ]] || { err "ECS service has no running tasks"; exit 1; }
  ok "ECS service running $running/$desired task(s)"
}

main() {
  parse_args "$@"
  discover_cluster
  check_http_redirect
  check_https_health
  check_tg_health
  check_ecs_service
  ok "ALB + ECS validation passed for ${DOMAIN_FQDN}"
}

main "$@"


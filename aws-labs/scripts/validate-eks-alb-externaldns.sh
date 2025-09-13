#!/usr/bin/env bash
set -Eeuo pipefail

# Validates Lab 18 – EKS ALB + ExternalDNS
# - IRSA roles exist (LBC + ExternalDNS)
# - ACM certificate is ISSUED

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
LAB_DIR="$ROOT_DIR/18-eks-alb-externaldns"

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

aws_cli() {
  aws --profile "$PROFILE" --region "$REGION" "$@"
}

read_tf_outputs() {
  require terraform; require jq
  terraform -chdir="$LAB_DIR" init -input=false >/dev/null
  local out
  out=$(terraform -chdir="$LAB_DIR" output -json)
  CERT_ARN=$(jq -r '.certificate_arn.value' <<<"$out")
  LBC_ROLE_ARN=$(jq -r '.lbc_role_arn.value' <<<"$out")
  EXTDNS_ROLE_ARN=$(jq -r '.externaldns_role_arn.value' <<<"$out")
}

check_roles() {
  [[ -n "$LBC_ROLE_ARN" && "$LBC_ROLE_ARN" != "null" ]] || { err "Missing lbc_role_arn output"; exit 1; }
  [[ -n "$EXTDNS_ROLE_ARN" && "$EXTDNS_ROLE_ARN" != "null" ]] || { err "Missing externaldns_role_arn output"; exit 1; }
  aws_cli iam get-role --role-name "${LBC_ROLE_ARN##*/}" >/dev/null
  aws_cli iam get-role --role-name "${EXTDNS_ROLE_ARN##*/}" >/dev/null
  ok "IRSA roles exist for LBC and ExternalDNS"
}

check_cert() {
  [[ -n "$CERT_ARN" && "$CERT_ARN" != "null" ]] || { err "Missing certificate_arn output"; exit 1; }
  local status
  status=$(aws_cli acm describe-certificate --certificate-arn "$CERT_ARN" --query 'Certificate.Status' --output text)
  [[ "$status" == "ISSUED" ]] || { err "ACM certificate not ISSUED (got: $status)"; exit 1; }
  ok "ACM certificate is ISSUED"
}

main() {
  require aws; require jq
  read_tf_outputs
  check_roles
  check_cert
  ok "ALB + ExternalDNS validation passed"
}

main "$@"


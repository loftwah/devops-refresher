#!/usr/bin/env bash
set -Eeuo pipefail

# Validates SGs from aws-labs/07-security-groups
# - Finds SG IDs from Terraform outputs (alb_sg_id, app_sg_id)
# - Checks ALB SG has ingress 80/443 (tcp) and egress all
# - Checks App SG has ingress from ALB SG on any single TCP port and egress all

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
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
  if [[ -z "${AWS_PROFILE_EFFECTIVE:-}" && -f "$SG_DIR/providers.tf" ]]; then
    AWS_PROFILE_EFFECTIVE=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$SG_DIR/providers.tf" || true)
  fi
  if [[ -z "${AWS_REGION_EFFECTIVE:-}" && -f "$SG_DIR/providers.tf" ]]; then
    AWS_REGION_EFFECTIVE=$(awk '/variable "region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$SG_DIR/providers.tf" || true)
  fi
  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"
}

read_tf_outputs() {
  require terraform
  require jq
  terraform -chdir="$SG_DIR" init -input=false >/dev/null
  local tf_json
  tf_json=$(terraform -chdir="$SG_DIR" output -json)
  ALB_SG_ID=$(jq -r '.alb_sg_id.value' <<<"$tf_json")
  APP_SG_ID=$(jq -r '.app_sg_id.value' <<<"$tf_json")
  [[ -n "$ALB_SG_ID" && "$ALB_SG_ID" != "null" ]] || { err "Missing alb_sg_id from outputs"; exit 1; }
  [[ -n "$APP_SG_ID" && "$APP_SG_ID" != "null" ]] || { err "Missing app_sg_id from outputs"; exit 1; }
  info "Found SGs: ALB=$ALB_SG_ID APP=$APP_SG_ID"
}

check_alb_sg() {
  local desc
  desc=$(aws_cli ec2 describe-security-groups --group-ids "$ALB_SG_ID")

  # Ingress 80 and 443 tcp present
  jq -e '.SecurityGroups[0].IpPermissions
          | map(select(.IpProtocol=="tcp" and .FromPort==80 and .ToPort==80))
          | length > 0' >/dev/null <<<"$desc" || { err "ALB SG missing TCP 80 ingress"; exit 1; }
  jq -e '.SecurityGroups[0].IpPermissions
          | map(select(.IpProtocol=="tcp" and .FromPort==443 and .ToPort==443))
          | length > 0' >/dev/null <<<"$desc" || { err "ALB SG missing TCP 443 ingress"; exit 1; }
  ok "ALB SG has 80 and 443 ingress rules"

  # Egress all (IpProtocol -1 and includes 0.0.0.0/0)
  jq -e '.SecurityGroups[0].IpPermissionsEgress
          | map(select(.IpProtocol=="-1" and (.IpRanges | map(select(.CidrIp=="0.0.0.0/0")) | length > 0)))
          | length > 0' >/dev/null <<<"$desc" || { err "ALB SG missing egress 0.0.0.0/0"; exit 1; }
  ok "ALB SG has egress 0.0.0.0/0"
}

check_app_sg() {
  local desc
  desc=$(aws_cli ec2 describe-security-groups --group-ids "$APP_SG_ID")
  # Any single tcp port from ALB SG
  local from_sg
  from_sg=$(jq -r \
    --arg ALB "$ALB_SG_ID" \
    '.SecurityGroups[0].IpPermissions[]?|select(.IpProtocol=="tcp")|select(.UserIdGroupPairs[]?.GroupId==$ALB)|[.FromPort,.ToPort]|@tsv' <<<"$desc" || true)
  [[ -n "$from_sg" ]] || { err "App SG missing ingress from ALB SG"; exit 1; }
  ok "App SG allows TCP from ALB SG (port $(cut -f1 <<<"$from_sg"))"

  local egress
  egress=$(jq -r '.SecurityGroups[0].IpPermissionsEgress[]?|[.IpProtocol,.IpRanges[]?.CidrIp//empty]|@tsv' <<<"$desc" || true)
  grep -q $'^-1\t0.0.0.0/0' <<<"$egress" || { err "App SG missing egress 0.0.0.0/0"; exit 1; }
  ok "App SG has egress 0.0.0.0/0"
}

main() {
  require aws; require jq
  parse_args "$@"
  discover_defaults
  read_tf_outputs
  check_alb_sg
  check_app_sg
  ok "Security groups validation passed"
}

main "$@"

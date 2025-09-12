#!/usr/bin/env bash
set -Eeuo pipefail

# Deploys Lab 12 (ALB) with DNS + ACM
# - Discovers ALB SG from Lab 07 outputs
# - Creates/validates ACM cert via Route53
# - Creates A record to ALB
#
# Defaults:
#   --hosted-zone aws.deanlofts.xyz
#   --domain demo-node-app-ecs.aws.deanlofts.xyz

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
LAB_DIR="$ROOT_DIR/aws-labs/12-alb"
SG_DIR="$ROOT_DIR/aws-labs/07-security-groups"

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
HOSTED_ZONE="aws.deanlofts.xyz"
DOMAIN_FQDN="demo-node-app-ecs.aws.deanlofts.xyz"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--profile) AWS_PROFILE_EFFECTIVE="$2"; shift 2 ;;
      -r|--region)  AWS_REGION_EFFECTIVE="$2";  shift 2 ;;
      -z|--hosted-zone) HOSTED_ZONE="$2"; shift 2 ;;
      -d|--domain) DOMAIN_FQDN="$2"; shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  -p, --profile NAME     AWS profile
  -r, --region  NAME     AWS region
  -z, --hosted-zone NAME Route53 hosted zone (default: $HOSTED_ZONE)
  -d, --domain FQDN      Domain for cert + A record (default: $DOMAIN_FQDN)
EOF
        exit 0 ;;
      *) err "Unknown argument: $1"; exit 2 ;;
    esac
  done
}

discover_defaults() {
  if [[ -z "${AWS_PROFILE_EFFECTIVE:-}" && -f "$LAB_DIR/providers.tf" ]]; then
    AWS_PROFILE_EFFECTIVE=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$LAB_DIR/providers.tf" || true)
  fi
  if [[ -z "${AWS_REGION_EFFECTIVE:-}" && -f "$LAB_DIR/providers.tf" ]]; then
    AWS_REGION_EFFECTIVE=$(awk '/variable "region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$LAB_DIR/providers.tf" || true)
  fi
  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"
}

read_sg_output() {
  require terraform
  terraform -chdir="$SG_DIR" init -input=false >/dev/null
  ALB_SG_ID=$(terraform -chdir="$SG_DIR" output -raw alb_sg_id)
  [[ -n "$ALB_SG_ID" ]] || { err "Could not fetch alb_sg_id from $SG_DIR"; exit 1; }
  info "Using ALB SG: $ALB_SG_ID"
}

apply_alb() {
  info "Applying Terraform in $LAB_DIR for domain $DOMAIN_FQDN"
  terraform -chdir="$LAB_DIR" init -input=false
  terraform -chdir="$LAB_DIR" apply \
    -auto-approve \
    -var alb_sg_id="$ALB_SG_ID" \
    -var hosted_zone_name="$HOSTED_ZONE" \
    -var certificate_domain_name="$DOMAIN_FQDN" \
    -var record_name="$DOMAIN_FQDN"
  ok "ALB applied. DNS and cert should validate shortly."
  terraform -chdir="$LAB_DIR" output
}

main() {
  parse_args "$@"
  discover_defaults
  read_sg_output
  apply_alb
}

main "$@"


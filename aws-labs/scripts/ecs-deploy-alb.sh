#!/usr/bin/env bash
set -Eeuo pipefail

# Deploys ALB with DNS + ACM (Primary entrypoint)
# - Discovers ALB SG from Security Groups outputs
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

PROFILE="devops-sandbox"
REGION="ap-southeast-2"
HOSTED_ZONE="aws.deanlofts.xyz"
DOMAIN_FQDN="demo-node-app-ecs.aws.deanlofts.xyz"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      # Profile/region are enforced by this lab; flags intentionally not supported
      -z|--hosted-zone) HOSTED_ZONE="$2"; shift 2 ;;
      -d|--domain) DOMAIN_FQDN="$2"; shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  (Profile/region are enforced by this lab: devops-sandbox / ap-southeast-2)
  -z, --hosted-zone NAME Route53 hosted zone (default: $HOSTED_ZONE)
  -d, --domain FQDN      Domain for cert + A record (default: $DOMAIN_FQDN)
EOF
        exit 0 ;;
      *) err "Unknown argument: $1"; exit 2 ;;
    esac
  done
}

discover_defaults() { info "Using AWS profile: $PROFILE"; info "Using AWS region:  $REGION"; }

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

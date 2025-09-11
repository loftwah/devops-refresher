#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
BOOTSTRAP_DIR="$ROOT_DIR/aws-labs/00-backend-bootstrap"
STATE_DIR="$ROOT_DIR/aws-labs/00-backend-terraform-state"

# Basic colored output (respects NO_COLOR and non-TTY)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }
}

parse_args() {
  PROFILE_FROM_ARGS=""
  REGION_FROM_ARGS=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--profile)
        PROFILE_FROM_ARGS="$2"; shift 2 ;;
      -r|--region)
        REGION_FROM_ARGS="$2"; shift 2 ;;
      --bucket)
        BUCKET_OVERRIDE="$2"; shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [--profile NAME] [--region NAME] [--bucket NAME]
  --profile, -p   AWS profile name to use for AWS CLI checks
  --region,  -r   AWS region to use for AWS CLI checks
  --bucket        Override bucket name (skip reading Terraform output)
EOF
        exit 0 ;;
      *)
        err "Unknown argument: $1"; exit 2 ;;
    esac
  done
}

aws_cli() {
  # Wrapper to pass --profile/--region if available
  local region_flag=( ) profile_flag=( )
  [[ -n "${AWS_REGION_EFFECTIVE:-}" ]] && region_flag=(--region "$AWS_REGION_EFFECTIVE")
  [[ -n "${AWS_PROFILE_EFFECTIVE:-}" ]] && profile_flag=(--profile "$AWS_PROFILE_EFFECTIVE")
  aws "${profile_flag[@]}" "${region_flag[@]}" "$@"
}

main() {
  parse_args "$@"
  require terraform
  require aws

  info "Terraform version: $(terraform version | head -n1)"

  # 1) Read bucket name from bootstrap outputs
  if [[ ! -d "$BOOTSTRAP_DIR" ]]; then
    err "Bootstrap dir not found: $BOOTSTRAP_DIR"; exit 1
  fi

  if [[ -n "${BUCKET_OVERRIDE:-}" ]]; then
    BUCKET="$BUCKET_OVERRIDE"
  else
    if ! BUCKET=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw state_bucket_name 2>/dev/null); then
      err "Unable to read 'state_bucket_name' from bootstrap outputs. Run 'terraform apply' in $BOOTSTRAP_DIR first, or pass --bucket."; exit 1
    fi
  fi

  info "Discovered state bucket: $BUCKET"

  # Determine AWS profile and region to use for CLI checks: args > env > providers.tf default
  PROFILE_DEFAULT=""; REGION_DEFAULT=""
  if [[ -f "$STATE_DIR/providers.tf" ]]; then
    PROFILE_DEFAULT=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$STATE_DIR/providers.tf" || true)
    REGION_DEFAULT=$(awk '/variable "aws_region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$STATE_DIR/providers.tf" || true)
  fi
  AWS_PROFILE_EFFECTIVE="${PROFILE_FROM_ARGS:-${AWS_PROFILE:-$PROFILE_DEFAULT}}"
  AWS_REGION_EFFECTIVE="${REGION_FROM_ARGS:-${AWS_REGION:-${AWS_DEFAULT_REGION:-$REGION_DEFAULT}}}"
  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"

  # Extract backend S3 region directly from backend.tf to avoid region mismatch
  BACKEND_REGION=""
  if [[ -f "$STATE_DIR/backend.tf" ]]; then
    BACKEND_REGION=$(awk '/backend[[:space:]]*"s3"[[:space:]]*{/,/}/ { if ($1=="region") { gsub(/"/, "", $3); print $3 } }' "$STATE_DIR/backend.tf" || true)
  fi
  [[ -n "$BACKEND_REGION" ]] && info "Using S3 backend region: $BACKEND_REGION"

  # 2) Validate S3 bucket exists
  # Always target S3 API calls at the backend region to handle env region mismatches
  if aws_cli s3api head-bucket --bucket "$BUCKET" ${BACKEND_REGION:+--region "$BACKEND_REGION"} >/dev/null 2>&1; then
    ok "S3 bucket exists"
  else
    err "S3 bucket missing: $BUCKET"; exit 1
  fi

  # 3) Validate backend state object exists
  KEY="global/s3/terraform.tfstate"
  if aws_cli s3api head-object --bucket "$BUCKET" --key "$KEY" ${BACKEND_REGION:+--region "$BACKEND_REGION"} >/dev/null 2>&1; then
    ok "State object exists: s3://$BUCKET/$KEY"
  else
    err "State object missing: s3://$BUCKET/$KEY. Did you run 'terraform init' in the state dir?"; exit 1
  fi

  # 4) Check backend config contains lockfile usage
  if grep -q 'backend\s\+"s3"' "$STATE_DIR/backend.tf" && grep -q 'use_lockfile\s*=\s*true' "$STATE_DIR/backend.tf"; then
    ok "Backend configured with lockfile"
  else
    err "Backend not configured with lockfile in: $STATE_DIR/backend.tf"; exit 1
  fi

  # 5) Ensure Terraform can read remote state
  terraform -chdir="$STATE_DIR" init -input=false >/dev/null
  if terraform -chdir="$STATE_DIR" state list >/dev/null 2>&1; then
    ok "Terraform can read remote state"
  else
    err "Terraform cannot read remote state from S3"; exit 1
  fi

  ok "Backend validation passed"
}

main "$@"

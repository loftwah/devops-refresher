#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
BOOTSTRAP_DIR="$ROOT_DIR/00-backend-bootstrap"
STATE_DIR="$ROOT_DIR/00-backend-terraform-state"

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
  # Wrapper to pass --profile/--region if available. Avoid unbound array expands under set -u.
  local cmd=(aws --cli-connect-timeout 5 --cli-read-timeout 10)
  # Add profile if set
  if [[ -n "${AWS_PROFILE_EFFECTIVE:-}" ]]; then
    cmd+=(--profile "$AWS_PROFILE_EFFECTIVE")
  fi
  # Only add default region if caller didn't pass one
  local has_region=0
  for a in "$@"; do
    if [[ "$a" == "--region" ]]; then has_region=1; break; fi
  done
  if [[ $has_region -eq 0 && -n "${AWS_REGION_EFFECTIVE:-}" ]]; then
    cmd+=(--region "$AWS_REGION_EFFECTIVE")
  fi
  cmd+=("$@")
  AWS_PAGER= AWS_MAX_ATTEMPTS=${AWS_MAX_ATTEMPTS:-3} "${cmd[@]}"
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

  # Determine AWS profile and region to use for CLI checks
  # Priority: CLI args > env > variables.tf defaults > backend.tf (profile only)
  PROFILE_DEFAULT=""; REGION_DEFAULT=""
  if [[ -f "$STATE_DIR/variables.tf" ]]; then
    PROFILE_DEFAULT=$(awk '/variable[[:space:]]+"aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$STATE_DIR/variables.tf" || true)
    REGION_DEFAULT=$(awk '/variable[[:space:]]+"aws_region"|variable[[:space:]]+"region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$STATE_DIR/variables.tf" || true)
  fi
  # Fallback: read profile from backend.tf if present
  if [[ -z "$PROFILE_DEFAULT" && -f "$STATE_DIR/backend.tf" ]]; then
    PROFILE_DEFAULT=$(awk '/backend[[:space:]]*"s3"[[:space:]]*{/,/}/ { if ($1=="profile") { gsub(/"/, "", $3); print $3 } }' "$STATE_DIR/backend.tf" || true)
  fi
  AWS_PROFILE_EFFECTIVE="${PROFILE_FROM_ARGS:-${AWS_PROFILE:-$PROFILE_DEFAULT}}"
  AWS_REGION_EFFECTIVE="${REGION_FROM_ARGS:-${AWS_REGION:-${AWS_DEFAULT_REGION:-$REGION_DEFAULT}}}"
  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"

  # Extract backend S3 region directly from backend.tf to avoid region mismatch
  BACKEND_REGION=""
  if [[ -f "$STATE_DIR/backend.tf" ]]; then
    # POSIX whitespace to locate backend block's region
    BACKEND_REGION=$(awk '/backend[[:space:]]*"s3"[[:space:]]*{/,/}/ { if ($1=="region") { gsub(/"/, "", $3); print $3 } }' "$STATE_DIR/backend.tf" || true)
  fi
  [[ -n "$BACKEND_REGION" ]] && info "Using S3 backend region: $BACKEND_REGION"

  # Print current caller account to catch cross-account issues
  if acct=$(aws_cli --region "${BACKEND_REGION:-${AWS_REGION_EFFECTIVE:-us-east-1}}" sts get-caller-identity --query Account --output text 2>/dev/null); then
    info "Caller account: $acct"
  else
    info "Caller account: <unknown>"
  fi

  # 2) Validate S3 bucket exists
  # Always target S3 API calls at the backend region to handle env region mismatches
  if ! out=$(aws_cli s3api head-bucket --bucket "$BUCKET" ${BACKEND_REGION:+--region "$BACKEND_REGION"} 2>&1); then
    err "S3 bucket check failed for '$BUCKET' in region '${BACKEND_REGION:-$AWS_REGION_EFFECTIVE}': $out"; exit 1
  fi
  ok "S3 bucket exists"

  # 3) Validate backend state object exists
  KEY="global/s3/terraform.tfstate"
  if ! out=$(aws_cli s3api head-object --bucket "$BUCKET" --key "$KEY" ${BACKEND_REGION:+--region "$BACKEND_REGION"} 2>&1); then
    err "State object check failed for s3://$BUCKET/$KEY: $out. Hint: run 'terraform init' in $STATE_DIR"; exit 1
  fi
  ok "State object exists: s3://$BUCKET/$KEY"

  # 4) Check backend config contains lockfile usage
  if grep -Eq 'backend[[:space:]]*"s3"' "$STATE_DIR/backend.tf" && grep -Eq 'use_lockfile[[:space:]]*=[[:space:]]*true' "$STATE_DIR/backend.tf"; then
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

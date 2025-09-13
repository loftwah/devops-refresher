#!/usr/bin/env bash
set -Eeuo pipefail

# Validates S3 app bucket from aws-labs/08-s3
# - Discover bucket name from Terraform outputs
# - Check bucket exists, versioning enabled, public access block enabled, default SSE AES256

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
S3_DIR="$ROOT_DIR/08-s3"

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
BUCKET_OVERRIDE=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--profile) AWS_PROFILE_EFFECTIVE="$2"; shift 2 ;;
      -r|--region)  AWS_REGION_EFFECTIVE="$2";  shift 2 ;;
      -b|--bucket)  BUCKET_OVERRIDE="$2";       shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  -p, --profile NAME   AWS profile
  -r, --region  NAME   AWS region
  -b, --bucket  NAME   Override bucket name (skip Terraform)
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
  if [[ -z "${AWS_PROFILE_EFFECTIVE:-}" && -f "$S3_DIR/providers.tf" ]]; then
    AWS_PROFILE_EFFECTIVE=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$S3_DIR/providers.tf" || true)
  fi
  if [[ -z "${AWS_REGION_EFFECTIVE:-}" && -f "$S3_DIR/providers.tf" ]]; then
    AWS_REGION_EFFECTIVE=$(awk '/variable "region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$S3_DIR/providers.tf" || true)
  fi
  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"
}

read_tf_outputs() {
  require terraform
  require jq
  terraform -chdir="$S3_DIR" init -input=false >/dev/null
  local tf_json
  tf_json=$(terraform -chdir="$S3_DIR" output -json)
  BUCKET_NAME=$(jq -r '.bucket_name.value' <<<"$tf_json")
  [[ -n "$BUCKET_NAME" && "$BUCKET_NAME" != "null" ]] || { err "Missing bucket_name from outputs; pass --bucket"; exit 1; }
  info "Bucket from outputs: $BUCKET_NAME"
}

check_bucket() {
  # Existence
  aws_cli s3api head-bucket --bucket "$BUCKET_NAME" >/dev/null 2>&1 || { err "Bucket not accessible/existing: $BUCKET_NAME"; exit 1; }
  ok "Bucket exists: $BUCKET_NAME"

  # Versioning
  local vs
  vs=$(aws_cli s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query 'Status' --output text)
  [[ "$vs" == "Enabled" ]] || { err "Versioning not enabled (got: $vs)"; exit 1; }
  ok "Versioning is enabled"

  # Public access block
  local pab
  pab=$(aws_cli s3api get-public-access-block --bucket "$BUCKET_NAME" --query 'PublicAccessBlockConfiguration' --output json 2>/dev/null || echo '{}')
  for k in BlockPublicAcls BlockPublicPolicy IgnorePublicAcls RestrictPublicBuckets; do
    grep -q "\"$k\": true" <<<"$pab" || { err "Public access block $k is not true"; exit 1; }
  done
  ok "Public access block is strict"

  # Default SSE
  local sse
  sse=$(aws_cli s3api get-bucket-encryption --bucket "$BUCKET_NAME" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text 2>/dev/null || true)
  [[ "$sse" == "AES256" || "$sse" == "aws:kms" ]] || { err "Default SSE not set (AES256/KMS). Got: ${sse:-none}"; exit 1; }
  ok "Default SSE configured: $sse"
}

main() {
  require aws
  parse_args "$@"
  discover_defaults
  if [[ -n "$BUCKET_OVERRIDE" ]]; then BUCKET_NAME="$BUCKET_OVERRIDE"; else read_tf_outputs; fi
  check_bucket
  ok "S3 validation passed"
}

main "$@"

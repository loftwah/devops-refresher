#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
EP_DIR="$ROOT_DIR/aws-labs/02-vpc-endpoints"

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
PROFILE_FROM_ARGS=""
REGION_FROM_ARGS=""
VPC_ID_OVERRIDE=""

EXPECTED_INTERFACE_SUFFIXES=("ssm" "ec2messages" "ssmmessages" "ecr.api" "ecr.dkr" "logs")
EXPECT_S3_GATEWAY=true

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  (Profile/region are enforced by this lab: devops-sandbox / ap-southeast-2)
      --vpc-id  ID     Override VPC ID (skip reading Terraform remote state)
      --no-s3          Do not expect S3 gateway endpoint
      --expect CSV     Override expected interface endpoints (e.g. ssm,ec2messages,ssmmessages,ecr.api,ecr.dkr,logs)
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      # Profile/region are enforced by this lab; flags intentionally not supported
      --vpc-id)     VPC_ID_OVERRIDE="$2";   shift 2 ;;
      --no-s3)      EXPECT_S3_GATEWAY=false; shift 1 ;;
      --expect)     IFS=',' read -r -a EXPECTED_INTERFACE_SUFFIXES <<< "$2"; shift 2 ;;
      -h|--help)    usage; exit 0 ;;
      *) err "Unknown argument: $1"; usage; exit 2 ;;
    esac
  done
}

aws_cli() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

discover_defaults() { info "Using AWS profile: $PROFILE"; info "Using AWS region:  $REGION"; }

read_vpc_from_state() {
  require terraform
  require jq

  if [[ -n "$VPC_ID_OVERRIDE" ]]; then
    VPC_ID="$VPC_ID_OVERRIDE"
    info "VPC ID provided via --vpc-id: $VPC_ID"
  else
    terraform -chdir="$EP_DIR" init -input=false >/dev/null
    # The endpoints stack itself does not expose the VPC ID; for now, require override or guess the first non-default VPC.
    VPC_ID=$(aws_cli ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].[VpcId]' --output text | head -n1 || true)
    if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
      err "Could not infer VPC ID. Pass --vpc-id or ensure VPC exists."; exit 1
    fi
    info "Guessed non-default VPC (may not be accurate): $VPC_ID"
  fi
}

check_gateway_s3() {
  if [[ "$EXPECT_S3_GATEWAY" != true ]]; then
    info "Skipping S3 gateway endpoint checks (--no-s3)"
    return 0
  fi
  local id service type
  # Avoid multiline parsing edge-cases by keeping this on one logical line
  read -r id service type < <(aws_cli ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=com.amazonaws.${REGION}.s3" --query 'VpcEndpoints[0].[VpcEndpointId,ServiceName,VpcEndpointType]' --output text || true)
  [[ "$id" != "None" && -n "$id" ]] || { err "S3 gateway endpoint not found"; exit 1; }
  [[ "$type" == "Gateway" ]] || { err "S3 endpoint is not type Gateway (got: $type)"; exit 1; }
  ok "S3 gateway endpoint present: $id"

  # Print associated route tables for visibility
  local rt_ids
  rt_ids=$(aws_cli ec2 describe-vpc-endpoints --vpc-endpoint-ids "$id" --query 'VpcEndpoints[0].RouteTableIds' --output text || true)
  info "  Associated route tables: ${rt_ids:-<none>}"
}

check_interface_endpoints() {
  local suffix svc id type dns_enabled subnets sgs
  for suffix in "${EXPECTED_INTERFACE_SUFFIXES[@]}"; do
    svc="com.amazonaws.${REGION}.${suffix}"
    # Keep to one logical line to avoid subshell parsing issues
    read -r id type dns_enabled subnets sgs < <(aws_cli ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=$svc" --query 'VpcEndpoints[0].[VpcEndpointId,VpcEndpointType,PrivateDnsEnabled,SubnetIds,Groups[].GroupId]' --output text || true)
    [[ "$id" != "None" && -n "$id" ]] || { err "Interface endpoint missing: $suffix"; exit 1; }
    [[ "$type" == "Interface" ]] || { err "Endpoint $suffix wrong type: $type"; exit 1; }
    [[ "$dns_enabled" == "True" ]] || { err "Endpoint $suffix PrivateDnsEnabled is False"; exit 1; }
    ok "Interface endpoint present: $suffix ($id)"
    info "  Subnets: ${subnets:-<none>} | SGs: ${sgs:-<none>}"
  done
}

main() {
  parse_args "$@"
  require aws
  discover_defaults
  read_vpc_from_state
  check_gateway_s3
  check_interface_endpoints
  ok "VPC endpoints validation (structure-only) passed"
  info "Note: Functional checks (ECR pulls, ECS Exec, Logs) validated in later labs."
}

main "$@"

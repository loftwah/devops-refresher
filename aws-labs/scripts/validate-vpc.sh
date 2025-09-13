#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
VPC_DIR="$ROOT_DIR/aws-labs/01-vpc"

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

AWS_PROFILE_EFFECTIVE=""
AWS_REGION_EFFECTIVE=""
PROFILE_FROM_ARGS=""
REGION_FROM_ARGS=""
VPC_ID_OVERRIDE=""
EXPECT_AZS=("ap-southeast-2a" "ap-southeast-2b")

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--profile) PROFILE_FROM_ARGS="$2"; shift 2 ;;
      -r|--region)  REGION_FROM_ARGS="$2";  shift 2 ;;
      --vpc-id)     VPC_ID_OVERRIDE="$2";   shift 2 ;;
      --expect-azs) IFS=',' read -r -a EXPECT_AZS <<< "$2"; shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  -p, --profile NAME      AWS profile to use (default from providers.tf or env)
  -r, --region  NAME      AWS region to use (default from env or variables.tf)
      --vpc-id ID         Override VPC ID (skip reading Terraform output)
      --expect-azs CSV    Expected AZs, e.g. ap-southeast-2a,ap-southeast-2b
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
  # Discover default profile from providers.tf in the VPC stack
  local profile_default=""
  if [[ -f "$VPC_DIR/providers.tf" ]]; then
    profile_default=$(awk '/variable "aws_profile"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$VPC_DIR/providers.tf" || true)
  fi
  AWS_PROFILE_EFFECTIVE="${PROFILE_FROM_ARGS:-${AWS_PROFILE:-$profile_default}}"

  # Discover default region: args > env > variables.tf default
  local region_default=""
  if [[ -f "$VPC_DIR/variables.tf" ]]; then
    region_default=$(awk '/variable "region"/,/}/ { if ($1=="default") { gsub(/"/, "", $3); print $3 } }' "$VPC_DIR/variables.tf" || true)
  fi
  AWS_REGION_EFFECTIVE="${REGION_FROM_ARGS:-${AWS_REGION:-${AWS_DEFAULT_REGION:-$region_default}}}"

  [[ -n "$AWS_PROFILE_EFFECTIVE" ]] && info "Using AWS profile: $AWS_PROFILE_EFFECTIVE"
  [[ -n "$AWS_REGION_EFFECTIVE"  ]] && info "Using AWS region:  $AWS_REGION_EFFECTIVE"
}

read_tf_outputs() {
  require terraform
  require jq

  if [[ -n "$VPC_ID_OVERRIDE" ]]; then
    VPC_ID="$VPC_ID_OVERRIDE"
    info "VPC ID provided via --vpc-id: $VPC_ID"
    PUBLIC_SUBNET_IDS=( )
    PRIVATE_SUBNET_IDS=( )
  else
    terraform -chdir="$VPC_DIR" init -input=false >/dev/null
    local tf_json
    tf_json=$(terraform -chdir="$VPC_DIR" output -json)
    VPC_ID=$(jq -r '.vpc_id.value' <<<"$tf_json")

    # Bash 3.2 compatible: avoid mapfile/readarray
    # Robust Bash 3.2-compatible array reads
    PUBLIC_SUBNET_IDS=()
    while IFS= read -r line; do [[ -n "$line" ]] && PUBLIC_SUBNET_IDS+=("$line"); done < <(jq -r '.public_subnet_ids.value[]' <<<"$tf_json")
    PRIVATE_SUBNET_IDS=()
    while IFS= read -r line; do [[ -n "$line" ]] && PRIVATE_SUBNET_IDS+=("$line"); done < <(jq -r '.private_subnet_ids.value[]' <<<"$tf_json")

    if [[ -z "$VPC_ID" || "$VPC_ID" == "null" ]]; then
      err "Could not read vpc_id from Terraform outputs. Ensure the stack is applied or pass --vpc-id."; exit 1
    fi
    info "Discovered VPC from outputs: $VPC_ID"
  fi
}

check_vpc_core() {
  local state is_default cidr
  read -r state is_default cidr < <(aws_cli ec2 describe-vpcs \
    --vpc-ids "$VPC_ID" \
    --query 'Vpcs[0].[State,IsDefault,CidrBlock]' \
    --output text)

  [[ "$state" == "available" ]] || { err "VPC not in 'available' state (got: $state)"; exit 1; }
  [[ "$is_default" == "False" ]] || { err "VPC is default; expected non-default"; exit 1; }
  ok "VPC exists and is non-default (CIDR: $cidr)"

  local dns_support dns_hostnames
  dns_support=$(aws_cli ec2 describe-vpc-attribute --vpc-id "$VPC_ID" --attribute enableDnsSupport --query 'EnableDnsSupport.Value' --output text)
  dns_hostnames=$(aws_cli ec2 describe-vpc-attribute --vpc-id "$VPC_ID" --attribute enableDnsHostnames --query 'EnableDnsHostnames.Value' --output text)
  [[ "$dns_support" == "True" && "$dns_hostnames" == "True" ]] || { err "DNS attributes not enabled (support=$dns_support, hostnames=$dns_hostnames)"; exit 1; }
  ok "DNS support + hostnames are enabled"
}

check_subnets() {
  # Expected CIDRs per design
  local -a expected_public=("10.64.0.0/20" "10.64.16.0/20")
  local -a expected_private=("10.64.32.0/20" "10.64.48.0/20")

  # Build the list of subnets to check. Prefer Terraform outputs if available.
  local subnets_raw
  local -a SUBNET_IDS
  if [[ ${#PUBLIC_SUBNET_IDS[@]:-0} -ge 1 || ${#PRIVATE_SUBNET_IDS[@]:-0} -ge 1 ]]; then
    SUBNET_IDS=("${PUBLIC_SUBNET_IDS[@]:-}" "${PRIVATE_SUBNET_IDS[@]:-}")
  else
    subnets_raw=$(aws_cli ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text | tr '\t' '\n' | sed '/^$/d')
    IFS=$'\n' read -r -a SUBNET_IDS <<< "$subnets_raw"
  fi

  (( ${#SUBNET_IDS[@]} >= 4 )) || { err "Expected at least 4 subnets, found ${#SUBNET_IDS[@]}"; exit 1; }

  # AZ coverage (only consider our subnets)
  local -a azs_list; azs_list=()
  local sid
  for sid in "${SUBNET_IDS[@]}"; do
    local az
    az=$(aws_cli ec2 describe-subnets --subnet-ids "$sid" --query 'Subnets[0].AvailabilityZone' --output text)
    azs_list+=("$az")
  done
  local unique_azs
  unique_azs=$(printf '%s\n' "${azs_list[@]}" | sort -u)
  local want
  for want in "${EXPECT_AZS[@]}"; do
    if ! grep -qx "$want" <<<"$unique_azs"; then
      err "Expected AZ not found among subnets: $want"; exit 1
    fi
  done
  ok "AZ spread includes: ${EXPECT_AZS[*]}"

  # Validate public/private classification and CIDRs; print details
  local -a discovered_public_cidrs; discovered_public_cidrs=()
  local -a discovered_private_cidrs; discovered_private_cidrs=()
  info "Subnets discovered:"
  for sid in "${SUBNET_IDS[@]}"; do
    local cidr map_pub name az
    read -r cidr map_pub name az < <(aws_cli ec2 describe-subnets --subnet-ids "$sid" \
      --query 'Subnets[0].[CidrBlock,MapPublicIpOnLaunch,Tags[?Key==`Name`].Value|[0],AvailabilityZone]' --output text)
    if [[ "$map_pub" == "True" || "$name" =~ ^staging-public- ]]; then
      discovered_public_cidrs+=("$cidr")
      info "  Public  $sid  AZ=$az  CIDR=$cidr  Name=${name:-<none>}"
    else
      discovered_private_cidrs+=("$cidr")
      info "  Private $sid  AZ=$az  CIDR=$cidr  Name=${name:-<none>}"
    fi
  done

  set_contains() { local needle="$1"; shift; local f=1; for x in "$@"; do [[ "$x" == "$needle" ]] && { f=0; break; }; done; return $f; }

  for cidr in "${expected_public[@]}"; do
    set_contains "$cidr" "${discovered_public_cidrs[@]:-}" || { err "Public CIDR missing: $cidr"; exit 1; }
  done
  for cidr in "${expected_private[@]}"; do
    set_contains "$cidr" "${discovered_private_cidrs[@]:-}" || { err "Private CIDR missing: $cidr"; exit 1; }
  done
  ok "Subnet CIDRs match expected public/private sets"
}

check_igw_nat_routes() {
  local igw_id
  igw_id=$(aws_cli ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' --output text)
  [[ "$igw_id" != "None" && -n "$igw_id" ]] || { err "No Internet Gateway attached to VPC"; exit 1; }
  ok "IGW attached: $igw_id"

  # NAT
  local nat_id nat_subnet nat_state alloc_id
  read -r nat_id nat_subnet nat_state alloc_id < <(aws_cli ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query 'NatGateways[0].[NatGatewayId,SubnetId,State,NatGatewayAddresses[0].AllocationId]' \
    --output text)
  [[ "$nat_id" != "None" && -n "$nat_id" ]] || { err "No NAT Gateway found"; exit 1; }
  [[ "$nat_state" == "available" ]] || { err "NAT Gateway not available (state: $nat_state)"; exit 1; }
  [[ -n "$alloc_id" && "$alloc_id" != "None" ]] || { err "NAT Gateway missing Elastic IP allocation"; exit 1; }
  # Ensure NAT subnet is public
  local nat_subnet_public
  nat_subnet_public=$(aws_cli ec2 describe-subnets --subnet-ids "$nat_subnet" --query 'Subnets[0].MapPublicIpOnLaunch' --output text)
  [[ "$nat_subnet_public" == "True" ]] || { err "NAT Gateway is not in a public subnet ($nat_subnet)"; exit 1; }
  ok "NAT present in public subnet $nat_subnet (state: $nat_state) with EIP $alloc_id"

  # Route tables: validate per-subnet associations and default routes; print targets
  local sid
  for sid in "${PUBLIC_SUBNET_IDS[@]:-}"; do
    local tgt_gw
    tgt_gw=$(aws_cli ec2 describe-route-tables \
      --filters "Name=association.subnet-id,Values=$sid" \
      --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId | [0]' \
      --output text)
    [[ "$tgt_gw" =~ ^igw- ]] || { err "Public subnet $sid does not default-route to IGW (got '${tgt_gw:-<none>}')"; exit 1; }
    info "  Public  $sid default route → IGW $tgt_gw"
  done
  ok "Public subnets default-route to IGW"

  for sid in "${PRIVATE_SUBNET_IDS[@]:-}"; do
    local rt_id tgt_gw tgt_nat
    rt_id=$(aws_cli ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$sid" --query 'RouteTables[0].RouteTableId' --output text)
    tgt_nat=$(aws_cli ec2 describe-route-tables \
      --filters "Name=association.subnet-id,Values=$sid" \
      --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId | [0]' \
      --output text)
    tgt_gw=$(aws_cli ec2 describe-route-tables \
      --filters "Name=association.subnet-id,Values=$sid" \
      --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId | [0]' \
      --output text)
    [[ "$tgt_nat" =~ ^nat- ]] || { err "Private subnet $sid (RT $rt_id) default route is not NAT (GatewayId='${tgt_gw:-<none>}', NatGatewayId='${tgt_nat:-<none>}')"; exit 1; }
    if [[ "$tgt_gw" =~ ^igw- ]]; then
      err "Private subnet $sid wrongly has IGW default route"; exit 1
    fi
    info "  Private $sid default route → NAT $tgt_nat (RT $rt_id)"
  done
  ok "Private subnets default-route to NAT and not IGW"
}

check_flow_logs_optional() {
  local fl
  fl=$(aws_cli ec2 describe-flow-logs --filter "Name=resource-id,Values=$VPC_ID" --query 'FlowLogs[].FlowLogId' --output text || true)
  if [[ -n "$fl" && "$fl" != "None" ]]; then
    ok "VPC Flow Logs are enabled (FlowLogIds: $fl)"
  else
    info "VPC Flow Logs are not enabled (expected default: OFF)"
  fi
}

check_tags() {
  # Verify baseline tags on VPC and subnets
  local -a keys=("Owner" "Project" "App" "Environment" "ManagedBy")
  local -a expected=("Dean Lofts" "devops-refresher" "devops-refresher" "staging" "Terraform")

  # VPC tags
  local v
  for i in "${!keys[@]}"; do
    v=$(aws_cli ec2 describe-vpcs --vpc-ids "$VPC_ID" --query "Vpcs[0].Tags[?Key=='${keys[$i]}'].Value|[0]" --output text)
    [[ "$v" == "${expected[$i]}" ]] || { err "VPC tag ${keys[$i]} expected '${expected[$i]}', got '${v:-<missing>}'"; exit 1; }
  done
  ok "VPC baseline tags present"

  # Subnet tags (sample all)
  local sid key expected_val got
  for sid in "${PUBLIC_SUBNET_IDS[@]:-}" "${PRIVATE_SUBNET_IDS[@]:-}"; do
    for i in "${!keys[@]}"; do
      key="${keys[$i]}"; expected_val="${expected[$i]}"
      got=$(aws_cli ec2 describe-subnets --subnet-ids "$sid" --query "Subnets[0].Tags[?Key=='$key'].Value|[0]" --output text)
      [[ "$got" == "$expected_val" ]] || { err "Subnet $sid missing tag $key='$expected_val' (got '${got:-<missing>}')"; exit 1; }
    done
  done
  ok "Subnet baseline tags present"
}

main() {
  parse_args "$@"
  require aws
  discover_defaults
  read_tf_outputs
  check_vpc_core
  check_subnets
  check_igw_nat_routes
  check_flow_logs_optional
  check_tags
  ok "VPC validation passed"
}

main "$@"

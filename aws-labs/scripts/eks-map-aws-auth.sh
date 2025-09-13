#!/usr/bin/env bash
set -Eeuo pipefail

# Map an IAM role into the EKS cluster's aws-auth ConfigMap.
# Purpose: grant kubectl/helm access for CI (e.g., CodeBuild role) or operators.
#
# Usage:
#   aws-labs/scripts/eks-map-aws-auth.sh <role-arn> [cluster-name] [region] [groups]
#
# Defaults:
#   - cluster-name: read from aws-labs/17-eks-cluster Terraform output
#   - region: ap-southeast-2
#   - groups: system:masters
#
# Notes:
#   - Requires: aws, kubectl, terraform, jq
#   - Idempotent: if the role mapping already exists, the script exits successfully.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

ROLE_ARN=${1:-}
CLUSTER_NAME=${2:-}
REGION=${3:-ap-southeast-2}
GROUPS_CSV=${4:-system:masters}

main() {
  require aws; require kubectl; require terraform; require jq
  [[ -n "$ROLE_ARN" ]] || { err "Usage: $0 <role-arn> [cluster-name] [region] [groups]"; exit 2; }

  if [[ -z "$CLUSTER_NAME" ]]; then
    local eks_dir
    eks_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/../17-eks-cluster && pwd)"
    terraform -chdir="$eks_dir" init -input=false >/dev/null || true
    CLUSTER_NAME=$(terraform -chdir="$eks_dir" output -raw cluster_name 2>/dev/null || true)
  fi
  [[ -n "$CLUSTER_NAME" ]] || { err "Could not determine cluster name (pass as arg 2 or ensure 17-eks-cluster outputs)"; exit 1; }

  info "Updating kubeconfig for cluster: $CLUSTER_NAME ($REGION)"
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

  # Fetch current aws-auth (or create a baseline if missing)
  tmp=$(mktemp)
  if kubectl -n kube-system get configmap aws-auth >/dev/null 2>&1; then
    kubectl -n kube-system get configmap aws-auth -o yaml > "$tmp"
  else
    cat >"$tmp" <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    []
YAML
  fi

  if grep -q "$ROLE_ARN" "$tmp"; then
    ok "Role already mapped in aws-auth: $ROLE_ARN"
    rm -f "$tmp"
    exit 0
  fi

  # Prepare YAML block for the role mapping
  username=${USERNAME_OVERRIDE:-codebuild}
  IFS=',' read -r -a groups <<< "$GROUPS_CSV"
  groups_yaml=""
  for g in "${groups[@]}"; do
    groups_yaml+=$'      - '"$g"$'\n'
  done

  mapping=$(cat <<EOF
    - rolearn: $ROLE_ARN
      username: $username
      groups:
$(printf "%s" "$groups_yaml")
EOF
)

  # If mapRoles is an empty JSON array placeholder, replace it; otherwise append
  if grep -q '^\s*mapRoles:\s*|\s*$' "$tmp"; then
    # Find the line after 'mapRoles: |' and append mapping with correct indentation
    awk -v block="$mapping" '
      BEGIN{printed=0}
      {print}
      /^\s*mapRoles:\s*\|\s*$/ && printed==0 {print block; printed=1}
    ' "$tmp" > "$tmp.new"
  else
    # Ensure mapRoles anchor exists
    if ! grep -q '^\s*mapRoles:\s*\|' "$tmp"; then
      # Add mapRoles key before end
      cat >> "$tmp" <<YAML
data:
  mapRoles: |
YAML
    fi
    awk -v block="$mapping" '
      {print}
      END{print block}
    ' "$tmp" > "$tmp.new"
  fi

  mv "$tmp.new" "$tmp"
  info "Applying updated aws-auth ConfigMap"
  kubectl apply -f "$tmp" >/dev/null
  rm -f "$tmp"
  ok "Mapped role into aws-auth: $ROLE_ARN (groups: $GROUPS_CSV)"
}

main "$@"


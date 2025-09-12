#!/usr/bin/env bash
set -Eeuo pipefail

# Deploys Lab 13 (ECS Cluster)

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
LAB_DIR="$ROOT_DIR/aws-labs/13-ecs-cluster"

# Basic colored output
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        echo "Usage: $(basename "$0")"; exit 0 ;;
      *) err "Unknown argument: $1"; exit 2 ;;
    esac
  done
}

apply_cluster() {
  info "Applying Terraform in $LAB_DIR (ECS cluster)"
  terraform -chdir="$LAB_DIR" init -input=false
  terraform -chdir="$LAB_DIR" apply -auto-approve
  ok "ECS cluster applied"
  terraform -chdir="$LAB_DIR" output
}

main() {
  parse_args "$@"
  apply_cluster
}

main "$@"


#!/usr/bin/env bash
set -uo pipefail

# Orchestrates all lab validators by invoking existing validate-*.sh scripts
# No flags required. Uses each script's own default discovery for profile/region.

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)
SCRIPTS_DIR="$ROOT_DIR/scripts"

# Basic colored output (respects NO_COLOR and non-TTY)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }

# Allow Ctrl-C (SIGINT) and TERM to stop the whole run immediately
trap 'echo; err "Interrupted"; exit 130' INT TERM

# Preferred execution order; skip if a script is missing.
PREFERRED=(
  validate-vpc.sh
  validate-security-groups.sh
  validate-vpc-endpoints.sh
  validate-s3.sh
  validate-rds.sh
  validate-redis.sh
  validate-ssm-params.sh
  validate-backend.sh
  validate-iam.sh
  validate-delegation.sh
  validate-demo-app-repo.sh
  validate-ecs-exec.sh
)

run_one() {
  local script_name="$1"
  local script_path="$SCRIPTS_DIR/$script_name"

  if [[ ! -x "$script_path" ]]; then
    if [[ -f "$script_path" ]]; then
      info "Skipping $script_name (not executable)"
    else
      info "Skipping $script_name (not found)"
    fi
    return 0
  fi

  info "Running $script_name"
  # Run and stream output. Do not exit on failure; collect status.
  if "$script_path"; then
    ok "$script_name passed"
    return 0
  else
    err "$script_name failed"
    return 1
  fi
}

main() {
  local failures=0 ran=0
  for s in "${PREFERRED[@]}"; do
    run_one "$s" || failures=$((failures+1))
    ran=$((ran+1))
  done

  # Also run any other validate-*.sh scripts not in PREFERRED (excluding self)
  shopt -s nullglob
  local others=()
  for path in "$SCRIPTS_DIR"/validate-*.sh; do
    base=$(basename "$path")
    [[ "$base" == "validate-labs.sh" ]] && continue
    # Skip ones already included
    if printf '%s\n' "${PREFERRED[@]}" | grep -qx -- "$base"; then
      continue
    fi
    others+=("$base")
  done
  shopt -u nullglob

  if (( ${#others[@]} > 0 )); then
    info "Discovered additional validators: ${others[*]}"
    for s in "${others[@]}"; do
      run_one "$s" || failures=$((failures+1))
      ran=$((ran+1))
    done
  fi

  info "Completed $ran validator(s)."
  if (( failures > 0 )); then
    err "$failures validator(s) failed"
    exit 1
  fi
  ok "All validators passed"
}

main "$@"

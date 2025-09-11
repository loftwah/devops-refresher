#!/usr/bin/env bash
set -Eeuo pipefail

# Validates that the demo app GitHub repository exists and is reachable
# Default repo: loftwah/demo-node-app

# Basic colored output (respects NO_COLOR and non-TTY)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET="\033[0m"; C_INFO="\033[36m"; C_OK="\033[32m"; C_FAIL="\033[31m"
else
  C_RESET=""; C_INFO=""; C_OK=""; C_FAIL=""
fi
info() { printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_OK}[ OK ]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_FAIL}[FAIL]${C_RESET} %s\n" "$*"; }

REPO_SLUG="loftwah/demo-node-app"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r|--repo) REPO_SLUG="$2"; shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: $(basename "$0") [options]
  -r, --repo owner/name   GitHub repo slug (default: $REPO_SLUG)
EOF
        exit 0 ;;
      *) err "Unknown argument: $1"; exit 2 ;;
    esac
  done
}

check_with_git() {
  command -v git >/dev/null 2>&1 || return 1
  git ls-remote --exit-code --heads "https://github.com/${REPO_SLUG}.git" >/dev/null 2>&1
}

check_with_curl() {
  command -v curl >/dev/null 2>&1 || return 1
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' "https://api.github.com/repos/${REPO_SLUG}")
  [[ "$code" == "200" ]]
}

main() {
  parse_args "$@"
  info "Checking GitHub repo: https://github.com/${REPO_SLUG}"
  if check_with_git; then
    ok "Repo exists and is reachable via git"
  elif check_with_curl; then
    ok "Repo exists (verified via GitHub API)"
  else
    err "Repo not reachable or does not exist: ${REPO_SLUG}"; exit 1
  fi
}

main "$@"

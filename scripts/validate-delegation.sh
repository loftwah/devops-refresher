#!/usr/bin/env bash
set -Eeuo pipefail

# Validate DNS subdomain delegation (NS + SOA) using public resolvers.
# Usage:
#   validate-delegation.sh --domain aws.deanlofts.xyz [--expect-ns ns1,ns2,...] [--resolver 1.1.1.1] [--verbose]

info() { printf "[INFO] %s\n" "$*"; }
ok()   { printf "[ OK ] %s\n" "$*"; }
err()  { printf "[FAIL] %s\n" "$*"; }

# Defaults for this repo
DOMAIN="aws.deanlofts.xyz"
EXPECT_NS_CSV="ns-136.awsdns-17.com.,ns-1412.awsdns-48.org.,ns-1623.awsdns-10.co.uk.,ns-630.awsdns-14.net."
RESOLVER="1.1.1.1"
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --expect-ns) EXPECT_NS_CSV="$2"; shift 2 ;;
    --resolver) RESOLVER="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") --domain <subdomain> [--expect-ns ns1,ns2,...] [--resolver IP] [--verbose]
Examples:
  $(basename "$0")
  # or override defaults
  $(basename "$0") --domain example.apps.example.com --expect-ns ns-1.example.,ns-2.example.
EOF
      exit 0 ;;
    *) err "Unknown arg: $1"; exit 2 ;;
  esac
done

command -v dig >/dev/null 2>&1 || { err "dig not found. Install 'bindutils' or 'dnsutils'."; exit 1; }

normalize_list() {
  # lowercases, strips surrounding spaces and trailing dots for comparison
  awk '{print tolower($0)}' | sed -e 's/[[:space:]]\+//g' -e 's/\.$//' | sort -u
}

get_ns() {
  dig NS "$DOMAIN" +short @"$RESOLVER" | sed '/^$/d'
}

get_soa() {
  dig SOA "$DOMAIN" +short @"$RESOLVER" | sed '/^$/d'
}

NS_ACTUAL_RAW=$(get_ns)
if [[ -z "$NS_ACTUAL_RAW" ]]; then
  err "No NS records returned for $DOMAIN from resolver $RESOLVER"; exit 1
fi
info "NS (via $RESOLVER):\n$NS_ACTUAL_RAW"

if [[ $VERBOSE -eq 1 ]]; then
  info "SOA: $(get_soa)"
fi

if [[ -n "$EXPECT_NS_CSV" ]]; then
  IFS=',' read -r -a EXP_ARR <<< "$EXPECT_NS_CSV"
  printf '%s\n' "${EXP_ARR[@]}" | normalize_list > /tmp/exp_ns.$$ 
  printf '%s\n' "$NS_ACTUAL_RAW" | normalize_list > /tmp/act_ns.$$ 

  if diff -u /tmp/exp_ns.$$ /tmp/act_ns.$$ >/dev/null; then
    ok "Delegation matches expected NS set"
  else
    err "Delegation NS mismatch. Expected vs Actual:" 
    diff -u /tmp/exp_ns.$$ /tmp/act_ns.$$ || true
    exit 1
  fi
else
  ok "Delegation NS discovered (no expected list provided)"
fi

if [[ $VERBOSE -eq 1 ]]; then
  info "Trace (first 30 lines):"
  dig +trace "$DOMAIN" | sed -n '1,30p' || true
fi

ok "DNS delegation validation passed for $DOMAIN"

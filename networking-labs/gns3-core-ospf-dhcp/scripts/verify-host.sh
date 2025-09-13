#!/usr/bin/env bash
set -euo pipefail

GW=${GW:-10.10.10.1}

echo "== IP config =="
ip -br addr
ip route

echo "== Ping default gateway =="
ping -c3 "$GW" || true

echo "== Trace to public DNS (may require Internet binding) =="
tracepath -n 1.1.1.1 || true

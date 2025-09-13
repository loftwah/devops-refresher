#!/usr/bin/env bash
set -euo pipefail

GW=${GW:-10.10.10.1}
WAN_IP=${WAN_IP:-}

echo "== IP config =="
ip -br addr
ip route

echo "== Ping default gateway =="
ping -c3 "$GW" || true

echo "== Trace to public DNS (may require Internet binding) =="
tracepath -n 1.1.1.1 || true

if [[ -n "${WAN_IP}" ]]; then
  echo "== Hairpin test to WAN_IP (HTTPS) =="
  set +e
  curl -m 5 -vk https://$WAN_IP/ || true
  set -e
fi

echo "== DNS resolution test =="
getent hosts example.com || true

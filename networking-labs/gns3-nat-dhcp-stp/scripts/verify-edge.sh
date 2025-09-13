#!/usr/bin/env bash
set -euo pipefail

WAN_IF=${WAN_IF:-eth0}
LAN_IF=${LAN_IF:-eth1}
WAN_IP=${WAN_IP:-}
SVC_IP=${SVC_IP:-10.10.20.10}

echo "== IP forwarding =="
cat /proc/sys/net/ipv4/ip_forward

echo "== nftables rules =="
nft list ruleset | sed -n '1,200p'

echo "== Interfaces =="
ip -br addr

if [[ -n "${WAN_IP}" ]]; then
  echo "== Hairpin/DNAT test from edge to WAN_IP (should hit $SVC_IP) =="
  set +e
  curl -m 5 -vk https://$WAN_IP/ || true
  set -e
fi

echo "== DNAT path check with tcpdump (10s) =="
timeout 10s tcpdump -ni any tcp port 443 -vv || true

echo "Done. Manually test from a LAN host and external node as needed."

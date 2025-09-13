#!/usr/bin/env bash
set -euo pipefail

echo "== OSPF neighbors =="
vtysh -c 'show ip ospf neighbor' || true

echo "== Routing table (default and internal) =="
vtysh -c 'show ip route' | sed -n '1,120p' || true

echo "== NAT rules (if nftables) =="
if command -v nft >/dev/null 2>&1; then
  nft list table ip nat || true
fi

echo "== Default route via WAN =="
ip route show default || true

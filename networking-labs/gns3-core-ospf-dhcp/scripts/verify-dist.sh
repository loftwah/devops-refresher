#!/usr/bin/env bash
set -euo pipefail

echo "== OSPF neighbors =="
vtysh -c 'show ip ospf neighbor' || true

echo "== Connected VLAN interfaces =="
ip -br addr | grep -E '\.(10|20) ' || true

echo "== DHCP relay traffic (10s) =="
timeout 10s tcpdump -ni any port 67 or port 68 -vv || true

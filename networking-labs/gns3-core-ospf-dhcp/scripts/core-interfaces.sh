#!/usr/bin/env bash
set -euo pipefail

# Core node interface and NAT setup
# Override these via environment as needed

WAN_IF=${WAN_IF:-eth0}
D1_IF=${D1_IF:-eth1}
D2_IF=${D2_IF:-eth2}

D1_IP=${D1_IP:-10.0.1.1/30}
D2_IP=${D2_IP:-10.0.2.1/30}
WAN_GW=${WAN_GW:-198.51.100.1}

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null

# Assign IPs
sudo ip addr add "$D1_IP" dev "$D1_IF" || true
sudo ip addr add "$D2_IP" dev "$D2_IF" || true
sudo ip link set "$D1_IF" up
sudo ip link set "$D2_IF" up

# Default route to internet
sudo ip route replace default via "$WAN_GW" dev "$WAN_IF"

# NAT for egress on WAN
if ! command -v nft >/dev/null 2>&1; then
  echo "nftables not installed; skipping NAT rules" >&2
  exit 0
fi

sudo nft -f - <<'EOF'
flush ruleset
table ip nat {
  chain postrouting { type nat hook postrouting priority 100; }
}
EOF
sudo nft add rule ip nat postrouting oifname "$WAN_IF" masquerade

echo "Core interfaces configured on $D1_IF,$D2_IF with NAT on $WAN_IF"

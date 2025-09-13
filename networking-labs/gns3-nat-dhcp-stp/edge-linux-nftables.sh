#!/usr/bin/env bash
set -euo pipefail

# Edge Linux NAT + DNAT + hairpin setup for GNS3 lab
# Adjust interfaces and WAN_IP as needed

WAN_IF=${WAN_IF:-eth0}
LAN_IF=${LAN_IF:-eth1}
WAN_IP=${WAN_IP:-198.51.100.10}

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null

# VLAN subinterfaces
sudo ip link add link "$LAN_IF" name "$LAN_IF.10" type vlan id 10 || true
sudo ip link add link "$LAN_IF" name "$LAN_IF.20" type vlan id 20 || true
sudo ip addr add 10.10.10.1/24 dev "$LAN_IF.10" || true
sudo ip addr add 10.10.20.1/24 dev "$LAN_IF.20" || true
sudo ip link set "$LAN_IF.10" up
sudo ip link set "$LAN_IF.20" up

# nftables rules
sudo nft -f - <<'EOF'
flush ruleset
table ip nat {
  chain prerouting { type nat hook prerouting priority -100; }
  chain postrouting { type nat hook postrouting priority 100; }
}
EOF

# shell expands variables now
sudo nft add rule ip nat postrouting oifname "$WAN_IF" masquerade
sudo nft add rule ip nat prerouting iifname "$WAN_IF" tcp dport 443 dnat to 10.10.20.10:443
sudo nft add rule ip nat prerouting iifname { "$LAN_IF.10", "$LAN_IF.20" } ip daddr $WAN_IP tcp dport 443 dnat to 10.10.20.10:443
sudo nft add rule ip nat postrouting oifname { "$LAN_IF.10", "$LAN_IF.20" } ip saddr 10.10.0.0/16 ip daddr 10.10.20.10 masquerade

echo "Configured NAT, DNAT, and hairpin rules on $WAN_IF and $LAN_IF.{10,20}"

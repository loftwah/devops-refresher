#!/usr/bin/env bash
set -euo pipefail

# Distribution B node interface setup

UPLINK_IF=${UPLINK_IF:-eth0}
TRUNK_IF=${TRUNK_IF:-eth1}

UPLINK_IP=${UPLINK_IP:-10.0.2.2/30}
VLAN10_IP=${VLAN10_IP:-10.10.10.1/24}
VLAN20_IP=${VLAN20_IP:-10.10.20.1/24}

sudo ip addr add "$UPLINK_IP" dev "$UPLINK_IF" || true
sudo ip link set "$UPLINK_IF" up

sudo ip link add link "$TRUNK_IF" name "$TRUNK_IF.10" type vlan id 10 || true
sudo ip link add link "$TRUNK_IF" name "$TRUNK_IF.20" type vlan id 20 || true
sudo ip addr add "$VLAN10_IP" dev "$TRUNK_IF.10" || true
sudo ip addr add "$VLAN20_IP" dev "$TRUNK_IF.20" || true
sudo ip link set "$TRUNK_IF" up
sudo ip link set "$TRUNK_IF.10" up
sudo ip link set "$TRUNK_IF.20" up

echo "Dist-B interfaces configured: uplink $UPLINK_IF, SVIs on $TRUNK_IF.{10,20}"

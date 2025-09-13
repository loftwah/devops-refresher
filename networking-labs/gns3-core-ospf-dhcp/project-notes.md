Project Notes: GNS3 Core + OSPF + DHCP

Node templates

- Linux Router (FRR): Debian/Ubuntu cloud image with FRR installed
- Linux Switch: plain Debian/Ubuntu with `bridge-utils`/`iproute2`
- Kea DHCP: Debian/Ubuntu with `kea-dhcp4-server`
- Internet: GNS3 Cloud node bound to your host NIC or NAT

Links

- core:eth1 ↔ dist-a:eth0 (10.0.1.0/30)
- core:eth2 ↔ dist-b:eth0 (10.0.2.0/30)
- dist-a:eth1 ↔ edge-1:eth0 (802.1Q trunk for VLANs 10,20)
- dist-b:eth1 ↔ edge-2:eth0 (802.1Q trunk for VLANs 10,20)
- edge-\* additional NICs to hosts as access ports
- core additional NIC to dhcp node

Bring-up order

1. Start core; run `scripts/core-interfaces.sh`; apply FRR config `frr/core/frr.conf`.
2. Start dist-a/dist-b; run `scripts/dist-*-interfaces.sh`; apply FRR configs.
3. Start edge switches; create `br0` and add ports; enable STP.
4. Start dhcp; place Kea config; start service.
5. Start hosts; obtain DHCP and test reachability; run OSPF verification.

Tips

- Save node snapshots after interface/scripts applied.
- Use `tcpdump -ni any` on dists to observe OSPF hellos and DHCP relays.

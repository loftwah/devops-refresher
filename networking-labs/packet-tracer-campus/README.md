Packet Tracer Campus Lab: NAT, DHCP, STP, Port Security

Overview

- Model a small campus with two access VLANs, an edge router doing NAT + port-forward, and STP protections.
- Use three devices: Edge Router (IOS), Dist Switch A (root), Dist Switch B (secondary), plus one Access switch and two hosts.

What, Why, When, How

- What: A minimal campus design exercising VLANs, trunks, DHCP, NAT/DNAT, STP protections, port-security, and storm-control.
- Why: These are the day‑one levers that keep small networks stable and secure; you’ll see them in most offices and branches.
- When: Use this pattern for small to medium offices where routed distribution isn’t required and a single edge provides internet.
- How: Edge does L3 (gateways via subinterfaces) and NAT; Dist switches are L2 aggregation (or L3 if extended); Access provides user/server ports with PortFast, BPDU Guard, storm control, and optional port-security.

Topology

```text
         Internet (DHCP)
               |
        [Edge Router]
             Gi0/0 (WAN)
             Gi0/1 (TRUNK VLAN10/20)
                 |
         [Dist A]====[Dist B]
             ||        ||
           [Access]--- H1 (VLAN10)
                \
                 \
                  SVC (VLAN20)
```

Files

- `edge-router.cfg` NAT overload, DNAT 443 to SVC, DHCP pools for VLAN10/20.
- `dist-a.cfg` STP root, trunks, VLANs.
- `dist-b.cfg` STP secondary, trunks, VLANs.
- `access-1.cfg` access ports with PortFast/BPDU Guard, storm-control, port-security.

Steps

1. Create VLAN 10 (Clients) and 20 (Servers) on Dist A/B and Access. Make uplinks trunks allowing 10,20.
2. On Edge: trunk on Gi0/1 with subinterfaces `.10` and `.20`. Assign gateways 10.10.10.1 and 10.10.20.1.
3. On Edge: enable NAT overload on Gi0/0, port-forward 443 to 10.10.20.10.
4. On Edge: configure DHCP pools for VLAN10/20.
5. On Dist A/B: set `rapid-pvst`, root and secondary priorities. On Access: PortFast/BPDU Guard on edge ports and storm-control.
6. Verify H1 gets an address in VLAN10, default gw 10.10.10.1, outbound internet via NAT.
7. Verify inbound HTTPS to Edge WAN forwards to SVC (10.10.20.10). For hairpin, prefer split DNS.
8. Loop test: cable between two Access edge ports; BPDU Guard should err-disable the port.

Notes

- Hairpin through IOS NAT may be inconsistent; use split-horizon DNS internally.
- If WAN uses PPPoE on the router, set MSS adjust and `ip nat outside` on the PPPoE dialer.

Verification commands

- NAT
  - `show ip nat translations` and `show ip nat statistics`
- DHCP
  - `show ip dhcp binding` and `show ip dhcp pool`
- STP
  - On Dist A: `show spanning-tree vlan 10`, expect root role and all forwarding uplinks
  - On Access: `show spanning-tree interface status`, `show errdisable recovery`, and interface status after BPDU Guard
- Port security & storm control
  - `show port-security interface gi0/2`
  - `show storm-control broadcast`
- VLANs and trunks
  - `show vlan brief`, `show interfaces trunk`

Scripts

- `scripts/verify-commands.md`: consolidated IOS verification commands by device.
- `scripts/loop-test-and-recovery.md`: safe BPDU Guard loop test and recovery steps.
- `scripts/apply-config-order.md`: recommended order to paste/apply configs and verify.

Examples & real‑world use cases

- Small branch with ISP modem: router gets public via DHCP; NAT overload for users; port‑forward 443 to a tiny on‑prem app; PortFast/BPDU Guard stop accidental loops from desk switches.
- Guest network split: VLAN20 for guests with separate DHCP pool and ACLs at the edge; production VLAN10 isolated; storm control limits broadcast abuse.
- Printer MAC reservations: combine DHCP reservation on the router with port‑security on the access port to reduce spoofing and accidental moves.

Learning outcomes

- Explain the roles of access/distribution/edge in a simple campus.
- Configure and verify VLANs, trunks, DHCP pools, and NAT/DNAT.
- Use STP features (PortFast, BPDU Guard) and storm‑control to mitigate loops and floods.
- Read and act on NAT, DHCP, and STP CLI outputs during troubleshooting.

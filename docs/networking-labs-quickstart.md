# Networking Labs Quick Start

Pick a single platform: GNS3 (standard here). Packet Tracer campus is included as a simple optional alternative.

Recommended learning path

1. NAT + DHCP + STP (Branch)

- Path: `networking-labs/gns3-nat-dhcp-stp/`
- Goals: SNAT/DNAT and hairpin NAT, DHCP reservations, STP loop recovery.
- Start with the README and run the verification scripts.

2. Core + OSPF + DHCP (Campus)

- Path: `networking-labs/gns3-core-ospf-dhcp/`
- Goals: OSPF neighbors, default route origination, DHCP relays, failover.
- Use FRR configs and interface scripts; validate with quick-verify scripts.

Optional

- Packet Tracer Campus: `networking-labs/packet-tracer-campus/` (fast fundamentals with IOS configs).

Tips

- Use the `project.gns3project.template` files to sketch topology; replace template names and IDs with your local templates.
- Persist NAT rules and FRR with `networking-labs/common/systemd/` examples on Debian/Ubuntu VMs.
- Keep snapshots/checkpoints after each milestone to accelerate retries.

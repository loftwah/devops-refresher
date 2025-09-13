Networking Labs

We standardize on GNS3 for all labs to keep tooling consistent and modern. Each lab folder includes a README with topology, steps, configs/scripts, and verification commands.

Scenarios

- gns3-nat-dhcp-stp: Small branch lab with NAT egress, DNAT/port‑forward, hairpin NAT, DHCP server, and STP loop mitigation.
- gns3-core-ospf-dhcp: Hierarchical campus lab with a core internet gateway, OSPF between core/distribution, L2 edges, and central DHCP with relays.

Getting started

- Install GNS3 and create nodes: Linux VMs/containers with FRR, Kea DHCP, and basic Linux bridges. Optionally add an “Internet” cloud bound to your host interface.
- Keep configs under version control and note interface mappings in the lab README.

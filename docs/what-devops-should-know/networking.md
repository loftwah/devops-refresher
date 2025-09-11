# What a Senior DevOps Engineer Should Know About Computer Networks

## 1. OSI vs TCP/IP and where HTTP fits

- What it is: OSI is a seven‑layer reference model for reasoning and troubleshooting. TCP/IP is the stack we actually configure on hosts and routers. HTTP is an application‑layer protocol that runs over a transport such as TCP or QUIC.
- Why it matters: Picking the right model helps you bound faults quickly and choose the correct configuration knobs.

```mermaid
flowchart LR
  subgraph OSI["OSI reference model"]
    L1["1 Physical"]-->L2["2 Data Link"]-->L3["3 Network"]-->L4["4 Transport"]-->L5["5 Session"]-->L6["6 Presentation"]-->L7["7 Application"]
  end
  subgraph TCPIP["TCP/IP as implemented"]
    T1["Link"]-->T2["Internet  IP  ICMP"]-->T3["Transport  TCP  UDP  QUIC"]-->T4["Application  HTTP  DNS  TLS"]
  end
```

Operate it in incidents

- Use OSI names to bound the fault. If hosts in one VLAN cannot ARP each other, that is Layer 2. If the default route is missing, that is Layer 3. If SYN packets leave but there is no SYN ACK, that is often Layer 4 or a stateful device.
- Use TCP/IP terms when configuring. You do not configure a Layer 5 setting on Linux. You configure TLS libraries, sockets, routes, and firewall rules.

Glossary you'll reuse

- ARP Address Resolution Protocol IPv4 to MAC mapping at Layer 2.
- NDP Neighbour Discovery Protocol IPv6 neighbour and router discovery.
- VLAN Virtual LAN using IEEE 802.1Q tags at Layer 2.
- STP Spanning Tree Protocol loop prevention at Layer 2.
- SVI Switch Virtual Interface a routed interface bound to a VLAN.
- LACP Link Aggregation Control Protocol 802.1AX bonding multiple links.
- VRF Virtual Routing and Forwarding separate routing tables on one device.
- CIDR Classless Inter Domain Routing flexible prefix lengths like 10.0.0.0/16.

---

## 2. HTTP the protocol and why versions matter

- What it is: HTTP defines request/response semantics (methods, status codes, headers, caching) and can run over different transports.
- Why it matters: Version and transport affect latency, multiplexing, and behaviour under loss or high RTT.

* HTTP/1.1 over TCP text framing with persistent connections. Serialising requests on one connection causes application head‑of‑line blocking.
* HTTP/2 over TCP binary frames and multiplexed streams on a single TCP connection. If TCP loses one segment, all streams on that connection pause until recovery.
* HTTP/3 over QUIC QUIC runs over UDP and provides streams without TCP head‑of‑line blocking. It integrates TLS 1.3 in the transport. Expect a faster handshake and better loss behaviour on lossy or high RTT paths.

Operate it

- Expose HTTP/2 and HTTP/3 at edges where your CDN or load balancer supports them. Keep HTTP/1.1 for fallbacks and legacy clients.
- During incidents, confirm what negotiated, then test alternates:

```bash
curl -v --http3 https://svc.example.com
curl -v --http2 https://svc.example.com
curl -v --http1.1 https://svc.example.com
```

What to look for in captures

- HTTP/1.1 look for serialised requests and slow responses when a single object is large.
- HTTP/2 look for stream resets and large bursts that correlate with TCP retransmissions.
- HTTP/3 look for multiple QUIC streams and transport errors. If a firewall blocks UDP/443 you may fall back to HTTP/2.

---

## 3. Physical media copper, fibre, optics, PoE

- What it is: The physical layer covers cables, optics, and power delivery.
- Why it matters: Many “mysterious” outages come from signal quality, dirty connectors, or power budget limits, not protocols.

### Copper twisted pair

- Cat5e one gigabit to 100 m. Some 2.5 GBASE T works on short good runs, but treat it as best effort.
- Cat6 one gigabit to 100 m, ten gigabit to about 55 m in dense bundles because of alien crosstalk.
- Cat6a ten gigabit to 100 m. Baseline for new runs in comms rooms.
- Cat8 25 or 40 gigabit to 30 m for top of rack and short room runs.

How to not get bitten

- Use factory made patch leads and test with a certifier where you can.
- Leave autonegotiation on both ends unless you have a documented reason. Hard setting one end and leaving the other on auto is a classic duplex mismatch.

### Fibre the parts that matter

Multimode fibre MMF

- Core is larger and supports many light paths modes. Cheap optics.
- Designations are OM3, OM4, OM5.
- Typical use short to medium runs inside rooms and buildings such as aggregation to distribution or server uplinks in the same row.
- Limits are about modal dispersion different modes arrive at different times. Modern optics mitigate some of this with better lasers and encoding.

Single mode fibre SMF

- Small core, one mode, laser light. Designation OS2.
- Typical use campus, building to building, metro, anything that might scale past 100 Gbps later.
- Because there is one mode, you avoid modal dispersion and can push much longer distances with the right optics.

Connectors and cleanliness

- LC connectors are the modern default on switch SFP cages. SC is still seen on older panels.
- Keep ferrules clean. A single speck of dust can increase bit error rates. If you see incrementing input errors and tiny packet loss under load, inspect and clean.

Optics and form factors

- SFP 1G. SFP plus 10G. SFP28 25G. QSFP28 100G. QSFP56 200G. QSFP DD 400G. The cage is a form factor. Speed is determined by the optic.
- Common optic codes by reach and medium
  - SR short reach over multimode.
  - LR long reach over single mode.
  - ER extended reach over single mode.
  - ZR very long reach over single mode.
    Check the data sheet for supported fibre type, launch power, receive sensitivity, and the optical budget. Do not trust folklore distances.

### PoE Power over Ethernet

Useful for phones, access points, and cameras. Know the per port and total power budget.

- 802.3af PoE up to about 13 W at the device.
- 802.3at PoE plus up to about 25 W.
- 802.3bt Type 3 up to about 51 W.
- 802.3bt Type 4 up to about 71 W.

---

## 4. Layer 2 MAC, ARP, NDP, VLANs, Spanning Tree

- What it is: Layer 2 moves frames inside a broadcast domain using MAC addresses.
- Why it matters: Most “can’t reach my neighbour” issues are L2 CAM tables, ARP/NDP, VLAN tags, or loops.

How a host talks to its neighbour in the same subnet

```mermaid
sequenceDiagram
  participant A as Host A  192.168.10.11
  participant B as Host B  192.168.10.20
  participant S as Switch
  A->>S: ARP who has 192.168.10.20
  B-->>A: ARP reply  192.168.10.20 is 00:11:22:33:44:55
  Note over A,B: A caches IP to MAC mapping in its ARP table
```

- CAM table content addressable memory on the switch maps destination MAC to output port.
- ARP IPv4 neighbour resolution. Look for entries stuck in incomplete if traffic is not flowing.
- IPv6 uses NDP Neighbour Discovery Protocol. It also includes Router Advertisements RA for stateless addressing and Duplicate Address Detection DAD.

VLANs and trunks

- An access port carries a single VLAN.
- A trunk carries many and tags frames with 802.1Q.
- Keep the concept of a native VLAN minimal and documented. A mismatch produces silent leaks across VLANs.

Spanning Tree Protocol STP

- Goal prevent loops. Without it, a looped frame multiplies and brings the segment down.
- Use RSTP Rapid STP or MSTP Multiple STP in modern designs.
- Keep Layer 2 domains small and push Layer 3 to the access so STP does very little.

STP viewed on a dual homed access switch

```mermaid
graph LR
  subgraph Dist
    D1[Distribution A]:::dist
    D2[Distribution B]:::dist
  end
  A1[Access switch]---D1
  A1---D2
  classDef dist fill:#eef,stroke:#55f
  linkStyle 1 stroke-dasharray: 6 3
```

The dashed link is likely in a blocking state. Routed access removes this behaviour by making both links Layer 3.

---

## 5. Switches and routers what they do and how to use them together

- What it is: Switches forward frames within a broadcast domain; routers forward packets between subnets.
- Why it matters: Knowing where to place L3 boundaries simplifies fault isolation and keeps failure domains small.

Design pattern you can defend in a review

- Small Layer 2 domains per access block.
- Inter VLAN routing on distribution or on routed access switches using SVIs.
- Aggregate server NICs with LACP to remove single uplink bottlenecks.
- VRFs to separate tenant or environment routing tables when VLAN boundaries are not enough.

---

## 6. IP addressing IPv4 and IPv6

- What it is: IP addressing labels interfaces so packets can be routed end to end.
- Why it matters: Clean, documented addressing plans prevent collisions, confusing NATs, and brittle firewall rules.

IPv4

- 32 bits written as dotted decimal. Use CIDR prefixes such as 10.20.30.0/24.
- Private address blocks RFC 1918 are 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16.
- APIPA Automatic Private IP Addressing 169.254.0.0/16 is link local only and usually indicates DHCP failure.

IPv6

- 128 bits written in hex with shorthand rules.
- Address types you will actually provision
  - Link local fe80::/10.
  - Unique Local Addresses ULA fc00::/7 for internal only.
  - Global unicast 2000::/3 for routed.

- Use a /64 per LAN. Do not try to save by carving host bits.
- Host addressing can come from SLAAC Stateless Address Autoconfiguration or from DHCPv6.

---

## 7. Subnet masks and CIDR step by step examples

- What it is: CIDR uses variable‑length prefixes to size networks to fit.
- Why it matters: Right‑sized subnets reduce waste while keeping broadcast domains manageable.

Definitions

- Prefix length the /n bit count.
- Subnet mask dotted decimal mask that aligns with the prefix.
- Network address the lowest address in the block.
- Broadcast address the highest address in an IPv4 block larger than a /31.

Worked example hosts first

- Requirement two subnets for about 50 hosts each.
- Formula usable hosts 2^(32 − prefix) minus 2.
- /26 has 64 addresses and 62 usable. Mask is 255.255.255.192.
- If the parent block is 192.168.10.0/24, the four /26s are:
  1. 192.168.10.0/26 usable .1 to .62 broadcast .63
  2. 192.168.10.64/26 usable .65 to .126 broadcast .127
  3. 192.168.10.128/26 usable .129 to .190 broadcast .191
  4. 192.168.10.192/26 usable .193 to .254 broadcast .255

Worked example subnets first

- Parent 10.20.0.0/16. Need six equal subnets.
- Each extra prefix bit doubles the subnet count.
- /19 gives 8 subnets plenty. Each is 8190 usable hosts.
- The third octet steps by 32 0, 32, 64, 96, 128, 160, 192, 224.

Finding a network for an IP by hand

- Example 192.168.14.37/27.
- /27 mask is 255.255.255.224 so the block size in the last octet is 256 minus 224 equals 32.
- The blocks are 0, 32, 64, 96, 128, 160, 192, 224.
- 37 falls in 32 to 63.
- Network 192.168.14.32/27. Usable .33 to .62. Broadcast .63.

Why /31 and /32 exist

- /31 is great for point to point links. There is no broadcast. Both addresses are usable.
- /32 is a single host loopbacks and virtual IPs. These are vital for routing protocol stability and for addressing services on multi homed hosts.

---

## 8. Subnetting cheat sheet with examples

- What it is: Handy reference for common IPv4 subnet sizes.
- Why it matters: You’ll size VLANs, point‑to‑point links, and management networks quickly during design and incidents.

Quick table for IPv4

| Prefix | Mask            | Addresses | Usable | Block step in varying octet | Typical use          |
| -----: | --------------- | --------- | -----: | --------------------------: | -------------------- |
|    /32 | 255.255.255.255 | 1         |      1 |                           1 | loopbacks, VIPs      |
|    /31 | 255.255.255.254 | 2         |      2 |                           2 | point to point       |
|    /30 | 255.255.255.252 | 4         |      2 |                           4 | legacy p2p           |
|    /29 | 255.255.255.248 | 8         |      6 |                           8 | tiny management nets |
|    /28 | 255.255.255.240 | 16        |     14 |                          16 | device VLANs         |
|    /27 | 255.255.255.224 | 32        |     30 |                          32 | small office VLANs   |
|    /26 | 255.255.255.192 | 64        |     62 |                          64 | medium VLANs         |
|    /25 | 255.255.255.128 | 128       |    126 |                         128 | large VLANs          |
|    /24 | 255.255.255.0   | 256       |    254 |            1 in third octet | route boundaries     |
|    /23 | 255.255.254.0   | 512       |    510 |            2 in third octet | bigger segments      |
|    /22 | 255.255.252.0   | 1024      |   1022 |            4 in third octet | summarisation        |
|    /21 | 255.255.248.0   | 2048      |   2046 |            8 in third octet | AZ wide management   |
|    /20 | 255.255.240.0   | 4096      |   4094 |           16 in third octet | DC row blocks        |
|    /19 | 255.255.224.0   | 8192      |   8190 |           32 in third octet | regional blocks      |
|    /18 | 255.255.192.0   | 16384     |  16382 |           64 in third octet | regional blocks      |
|    /17 | 255.255.128.0   | 32768     |  32766 |          128 in third octet | large site           |
|    /16 | 255.255.0.0     | 65536     |  65534 |           1 in second octet | campus or VPC scope  |

Visualising a split

```mermaid
flowchart LR
  P["Parent 192.168.10.0/24"] --> S["Split into 4 x /26  step 64"]
  S --> A["192.168.10.0/26"]
  S --> B["192.168.10.64/26"]
  S --> C["192.168.10.128/26"]
  S --> D["192.168.10.192/26"]
```

IPv6 reminders

- Use a /64 per LAN. Hosts rely on that size for SLAAC.
- Plan with /48 or /56 per site so you can hand out as many /64s as you need.
- There is no broadcast in IPv6. Use NDP for neighbour discovery.

---

## 9. Services DHCP and APIPA

- What it is: DHCP automates address assignment; APIPA is IPv4 link‑local self‑assignment when DHCP fails.
- Why it matters: Misconfigured DHCP or helpers cause widespread outages and puzzling 169.254.x.x addresses.

DHCPv4 performs DORA Discover, Offer, Request, Acknowledge. It also carries options such as default gateway and DNS.

```mermaid
sequenceDiagram
  participant H as Host
  participant S as DHCP server
  H->>S: DHCPDISCOVER  broadcast
  S-->>H: DHCPOFFER
  H->>S: DHCPREQUEST
  S-->>H: DHCPACK
```

How to harden

- Enable DHCP snooping on access switches to block rogue servers.
- Combine snooping with Dynamic ARP Inspection to stop common spoofing tricks.
- Log every allocation and bind the log to change tickets for audits.

APIPA

- If a host cannot reach DHCP, it may self assign 169.254.x.x so it can at least talk on that link. Treat this as a clear signal to check cabling, VLANs, and IP helper addresses on the gateway.

---

## 10. TCP, UDP, ICMP and PMTUD

- What it is: Transport and control protocols that deliver bytes and report errors.
- Why it matters: Tuning or filtering here changes latency, throughput, and black‑hole behaviours.

TCP Transmission Control Protocol

- Reliable and ordered delivery. Three way handshake, retransmissions, congestion and flow control.
- Tuning you will actually touch listen backlog, `tcp_fin_timeout`, and socket buffer sizes under heavy churn.

UDP User Datagram Protocol

- Connectionless and message oriented. Good for DNS, telemetry, and as a substrate for QUIC.

ICMP Internet Control Message Protocol

- Carries error reporting and Path MTU Discovery PMTUD.
- If you block ICMP too broadly, PMTUD fails and large packets black hole. Permit the needed types on firewalls.

How to test quickly

- `ss -ti` to inspect TCP state. Look for retransmits and cwnd stalls.
- `tracepath` for PMTUD behaviour.
- `tcpdump -ni any -c 500 -w /tmp/trace.pcap` when you need proof.

---

## 11. Network topologies and Spanning Tree behaviour

- What it is: Common ways to connect hosts, switches, and routers.
- Why it matters: Topology choices determine failure domains, convergence, and whether STP is active or bored.

Star the classic office

- Access switches connect to a distribution pair. Simple to reason about.
- Dual uplinks from access to distribution are common. In pure Layer 2 designs, STP will block one path.

```mermaid
graph TD
  H1((Host))-->A[Access]
  H2((Host))-->A
  A-->D1[Distribution A]
  A-->D2[Distribution B]
  linkStyle 2 stroke-dasharray: 6 3
```

Leaf spine the data centre pattern

- Leaves connect to servers. Spines connect to leaves. No east west bottleneck and predictable hop count.
- Routing is normally Layer 3 everywhere with ECMP multipath. STP is effectively idle.

Hub and spoke WANs and cloud

- Spokes connect to a central hub such as AWS Transit Gateway.
- Simpler security, obvious traffic inspection points, and clear failure domains.

Overlays

- VXLAN EVPN for modern DC fabrics.
- GRE, IPSec or WireGuard for site to site and service meshes.

---

## 12. Ubuntu networking in 2025 setup

- What it is: Netplan generates systemd‑networkd (Server) or NetworkManager (Desktop) configs from YAML.
- Why it matters: Safe rollouts and clear YAML patterns prevent lockouts on remote systems.

Ubuntu Server uses Netplan which renders to systemd networkd by default. Desktop renders to NetworkManager. Use `sudo netplan try` before `sudo netplan apply` when remote so you can auto rollback.

DHCP on a NIC

```yaml
# /etc/netplan/01-dhcp.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: true
      dhcp6: true
```

Static dual stack with routes and DNS

```yaml
# /etc/netplan/02-static.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      addresses:
        - 198.51.100.10/24
        - 2001:db8:100:200::10/64
      routes:
        - to: 0.0.0.0/0
          via: 198.51.100.1
        - to: ::/0
          via: 2001:db8:100:200::1
      nameservers:
        addresses: [203.0.113.53, 2001:db8:53::1]
        search: [example.internal]
```

VLAN on a trunk

```yaml
# /etc/netplan/10-vlan.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp2s0: {}
  vlans:
    vlan100:
      id: 100
      link: enp2s0
      addresses: [192.0.2.10/24]
      routes:
        - to: 0.0.0.0/0
          via: 192.0.2.1
```

Bridge for KVM with a VLAN uplink

```yaml
# /etc/netplan/20-bridge.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0: {}
  vlans:
    uplink.200:
      id: 200
      link: enp3s0
  bridges:
    br200:
      interfaces: [uplink.200]
      addresses: [203.0.113.10/27]
      parameters:
        stp: true
        forward-delay: 4
```

LACP bond for redundancy

```yaml
# /etc/netplan/30-bond.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp4s0: {}
    enp5s0: {}
  bonds:
    bond0:
      interfaces: [enp4s0, enp5s0]
      parameters:
        mode: 802.3ad
        mii-monitor-interval: 100
      addresses: [10.0.0.10/24]
      gateway4: 10.0.0.1
```

DNS on Ubuntu

- Use `resolvectl status` and `resolvectl query`.
- Confirm `/etc/resolv.conf` points at the systemd stub unless you manage it yourself.
- On Desktop, set `renderer: NetworkManager` if you want NetworkManager to own the interface.

---

## 13. Troubleshooting on Ubuntu in 2025

- What it is: A pragmatic flow from physical → IP → DNS → transport → packets.
- Why it matters: Quick, repeatable checks shorten incidents and avoid rabbit holes.

First minute triage that actually finds faults

1. Physical `ip -br link` and `dmesg | grep -i enp1s0`. If link is flapping, fix that first.
2. Addressing `ip -br addr` then `ip route` and `ip -6 route`. No default route means no internet.
3. DNS `resolvectl status` then `resolvectl query example.com`.
4. Connectivity `ping -c3 198.51.100.1`, then `tracepath 1.1.1.1` and `tracepath -6 2606:4700:4700::1111`.
5. Sockets `ss -tupn | head -n 30`. Find LISTEN and ESTABLISHED, look for SYN SENT.
6. Packets `sudo tcpdump -ni any not port 22 -c 400 -w /tmp/cap.pcap`.

Netplan safe workflow

- `sudo netplan generate` to validate.
- `sudo netplan try` to test with rollback.
- `sudo netplan apply` to commit.

When routing is weird

- `ip rule` and `ip route show table all`.
- Look for policy routing that sends replies out a different interface classic asymmetric path problems.

---

## 14. Troubleshooting with block diagrams

- What it is: A lightweight method to visualise the path and test each hop.
- Why it matters: It keeps you systematic under pressure and reveals where policy or NAT changes behaviour.

Draw only the necessary blocks between client and service. Test hop by hop. At each boundary, test both ways. Capture on ingress and egress to any policy device.

```mermaid
flowchart TD
  C[Client] --> A[Access switch]
  A --> D[Distribution  SVIs]
  D --> FW[Firewall or NAT]
  FW --> W[WAN or Transit]
  W --> EDGE[DC Edge or Cloud GW]
  EDGE --> LB[Load balancer]
  LB --> S[Service]
```

For each block

- Inputs and outputs
- Decision taken forward, drop, translate
- State tables to inspect MAC tables, ARP or neighbour caches, routes, NAT translations, ACL counters
- Proof packet capture on both sides

---

## 15. Routing protocols OSPF and BGP what, when, why, how

- What it is: Interior (OSPF) and exterior (BGP) routing protocols that compute paths and enforce policy.
- Why it matters: They decide reachability and failover. Clean policy prevents leaks and surprises at scale.

OSPF Open Shortest Path First

- What link state interior protocol. OSPFv2 for IPv4 and OSPFv3 for IPv6. Areas split large networks. Design for a contiguous backbone called area 0.
- When one administrative domain like a campus or data centre where you need fast convergence and equal cost multipath.
- Why every router knows the topology, so convergence is predictable. Summarise at Area Border Routers ABRs to limit churn.
- How point to point interfaces for clarity, consistent interface costs, and passive interfaces on user facing VLANs.

Minimal FRR example

```text
router ospf
 router-id 198.51.100.1
 passive-interface default
 no passive-interface enp1s0
 network 198.51.100.0/24 area 0
```

Minimal Cisco IOS example

```text
router ospf 10
 router-id 203.0.113.3
 network 10.10.10.0 0.0.0.255 area 0
```

BGP Border Gateway Protocol

- What path vector protocol. Uses attributes such as AS PATH, NEXT HOP, LOCAL PREF, MED, and communities to pick paths.
- When peering with ISPs, between organisations, or as a policy control plane internally. Essential for hybrid cloud and multi VPC.
- Why explicit policy. You decide what leaves and what enters. Scales globally.
- How strict route filters, `max-prefix` safeguards, and consistent community tagging. Use LOCAL PREF to steer egress within your AS. Use AS PATH prepending as a last resort to influence inbound when you cannot set neighbour policy.

Minimal FRR eBGP example

```text
router bgp 65010
 bgp router-id 203.0.113.10
 neighbor 198.51.100.254 remote-as 64512
 !
 address-family ipv4 unicast
  network 203.0.113.0/24
  neighbor 198.51.100.254 activate
 exit-address-family
 !
 address-family ipv6 unicast
  network 2001:db8:100::/48
  neighbor 2001:db8:ffff::254 remote-as 64512
  neighbor 2001:db8:ffff::254 activate
 exit-address-family
```

What to log and alert

- OSPF adjacency changes and LSA floods out of cycle.
- BGP session flaps, changes in advertised prefixes, and max prefix alarms.
- Keep a plain text policy document with example routes and intended attributes so you can verify with `show ip bgp` or `vtysh -c "show bgp ..."`.

---

## 16. Cisco campus design why it still matters

- What it is: A hierarchical Access → Distribution → Core model, often with routed access.
- Why it matters: Predictable failure domains, simple summaries, and fewer STP headaches.

The classic hierarchical model is Access, Distribution, Core. The reasons it persists

- Predictable fault domains and blast radii.
- Modularity and clear summaries at each tier.
- Easy to adopt routed access Layer 3 from access to distribution so that Spanning Tree has very little to do.

Useful refinements in 2025

- Virtual chassis or StackWise at access for simplified management.
- MLAG or virtual switching at distribution so an access switch can dual home without blocked ports.
- Summarise at distribution. Keep area 0 at distribution if you use OSPF.
- Place Layer 3 close to the edge to keep broadcast domains small.

---

## 17. Networking in AWS what you must know

- What it is: VPC primitives for routing, security, and hybrid connectivity.
- Why it matters: Costs and defaults can bite; the right constructs simplify connectivity and governance.

VPC Virtual Private Cloud

- Plan non overlapping CIDRs with on prem. Decide early if you want IPv6.
- Subnets are Availability Zone scoped. Route tables attach to subnets.
- Internet Gateway IGW provides public internet access for public subnets.
- NAT Gateway NGW provides outbound internet for private subnets. It charges per hour and per gigabyte.
- VPC endpoints
  - Gateway endpoints S3 and DynamoDB route at the route table.
  - Interface endpoints PrivateLink give you private access to AWS services and third parties without routing full CIDRs.

Security

- Security Groups are stateful and attach to ENIs elastic network interfaces.
- Network ACLs are stateless and attach to subnets. Use them sparingly.
- VPC Flow Logs help you see accepted and rejected traffic.

Hybrid and multi VPC

- Transit Gateway TGW is a regional hub for many VPCs and on prem. Use TGW instead of complex peering meshes.
- VPC peering is simple and non transitive. Good for small numbers of VPCs.
- PrivateLink is ideal when you produce or consume a single application privately.

IPv6 in AWS

- Assign an IPv6 block to the VPC. Give each subnet a /64.
- Use an egress only internet gateway for IPv6 outbound from private subnets.
- Many services including load balancers and EKS support dual stack.

A small dual stack VPC at a glance

```mermaid
flowchart LR
  subgraph VPC
    subgraph Public subnets  AZ A and B
      ALB[ALB]-->W1[Web nodes]
    end
    subgraph Private subnets  AZ A and B
      A1[App nodes]-->DB[(RDS)]
    end
  end
  ALB-->IGW[Internet Gateway]
  A1-->VPCE[Gateway  S3]
  A1-->NAT[NAT GW]-.->IGW
  VPC---TGW[Transit Gateway]
```

Cost traps you will actually hit

- NAT data processing adds up if your apps pull or push to S3. Use S3 Gateway Endpoints.
- Interface endpoints charge per hour and per gigabyte. Prefer Gateway endpoints when possible.
- Cross AZ data has a cost. This matters for chatty microservices.

---

## Sources and credibility

Primary references you can cite in reviews

- RFC 791 IPv4. RFC 4632 CIDR. RFC 1918 private IPv4.
- RFC 826 ARP. RFC 4861 IPv6 Neighbour Discovery. RFC 8200 IPv6.
- RFC 2131 DHCPv4. RFC 3927 IPv4 link local APIPA.
- RFC 768 UDP. RFC 792 ICMP. RFC 4443 ICMPv6. RFC 1191 and RFC 8201 PMTUD.
- HTTP RFC 9110 semantics, RFC 9112 HTTP/1.1, RFC 9114 HTTP/3.
- IEEE 802.1Q VLAN tagging. IEEE 802.1D STP with RSTP 802.1w and MSTP 802.1s.
- IEEE 802.3 Ethernet including PoE amendments.
- FRRouting user guides for OSPF and BGP configuration.
- Cisco campus design guides for hierarchical and routed access models.
- AWS official documentation for VPC, NAT Gateway, Transit Gateway, and PrivateLink.
- Canonical Netplan and systemd resolved documentation.

---

## Final checklist and quick grabs

- Use OSI words to scope the fault. Configure with TCP/IP thinking.
- For HTTP incidents, confirm the negotiated version and test alternates.
- Keep Layer 2 domains small. Push Layer 3 to the access to render STP boring.
- Memorise private ranges and the /31 and /32 special cases.
- Use Netplan try on remote Ubuntu changes.
- In AWS, kill NAT hairpins with Gateway Endpoints and PrivateLink.

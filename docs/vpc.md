# AWS VPC Explanation

## 1. What a VPC Is

An Amazon Virtual Private Cloud (VPC) is a logically isolated section of the AWS cloud where you can launch resources in a defined network.  
You control IP ranges, subnets, route tables, gateways, and security boundaries.

---

## 2. Core Components

- **CIDR block**: Defines the IP address range of the VPC.
- **Subnets**: Segments of the VPC CIDR in specific Availability Zones.
  - **Public subnet**: Has a route to an Internet Gateway (IGW).
  - **Private subnet**: No direct route to the internet; can route outbound via NAT.
- **Route tables**: Define how traffic is routed (local VPC, IGW, NAT GW, VPC endpoints, VPN, Transit Gateway).
- **Gateways**:
  - **Internet Gateway (IGW)**: Two-way internet traffic for public subnets.
  - **NAT Gateway (NAT GW)**: Outbound-only internet access for private subnets.
  - **Egress-only Internet Gateway**: Outbound-only for IPv6.
  - **VPC Endpoints**: Private connections to AWS services without using the internet.
- **Security Groups and NACLs**: Stateful and stateless firewalls at the resource and subnet level.

---

## 3. Routing Patterns

### 3.1 Public Subnet with Internet Gateway

- Route table has `0.0.0.0/0` → IGW.
- Resources can send traffic to the internet and accept inbound traffic.
- Typical use: ALBs, bastion hosts, public web servers.

```mermaid
flowchart LR
  Internet((Internet)) <--> IGW
  IGW <--> SubnetPub[Public Subnet]
  SubnetPub --- EC2Pub[EC2: Public]
```

---

### 3.2 Private Subnet with NAT Gateway

- Route table has `0.0.0.0/0` → NAT GW.
- NAT GW sits in a **public subnet** with a route to IGW.
- Private resources get outbound internet but block inbound initiated traffic.

Key behaviors:

- Routes live on the subnet’s associated route table. You don’t configure “both sides” as with physical routers; AWS handles return paths for established flows.
- A NAT Gateway requires an Elastic IP and must be placed in a public subnet to forward to the IGW.

```mermaid
flowchart LR
  Internet((Internet)) <--> IGW
  IGW <--> SubnetPub[Public Subnet]
  SubnetPub --- NATGW[NAT Gateway]

  NATGW <--> SubnetPriv[Private Subnet]
  SubnetPriv --- EC2Priv[EC2: Private]
```

---

### 3.3 Private Subnet with VPC Endpoints

- Instead of NAT, private subnets route to **VPC endpoints** for AWS services.
- Gateway endpoints: S3, DynamoDB.
- Interface endpoints: most other services.
- Saves NAT data processing costs.

```mermaid
flowchart LR
  SubnetPriv[Private Subnet] --- EC2Priv[EC2]
  SubnetPriv <--> VPCEndpoint[VPC Endpoint]
  VPCEndpoint <--> S3[(S3)]
```

---

### 3.4 IPv6 with Egress-Only IGW

- Outbound IPv6 traffic possible without NAT.
- Inbound initiated traffic is blocked.

---

## 4. Why You Need an IGW with NAT GW

- A NAT GW must live in a **public subnet** (subnet with a default route to an IGW).
- NAT forwards traffic from private subnets to the IGW for the internet.
- Without an IGW, a NAT GW cannot send traffic out.

Think of it like:

- **IGW = the door to the internet.**
- **NAT GW = a one-way turnstile for private subnets to use that door.**

---

## 5. Cost Considerations

- **IGW**: No hourly cost.
- **NAT GW**: Hourly charge + per-GB data processing.
- **VPC Endpoints**: Gateway endpoints are free; interface endpoints have hourly + per-GB fees.
- Optimisation:
  - Use VPC endpoints for S3/DynamoDB to cut NAT costs.
  - Deploy NAT GW in each AZ to avoid cross-AZ charges.
  - Keep only resources that must be public in public subnets.

Best practices:

- For high availability, provision one NAT GW per AZ and point each private subnet’s route table to its AZ‑local NAT GW.
- Control the VPC’s main route table explicitly and associate every subnet with an intended route table to avoid surprises.

---

## 6. Summary

- A VPC gives you complete control over AWS networking.
- Public subnets need IGWs for two-way internet.
- Private subnets can use NAT GWs for outbound or VPC endpoints for private service access.
- A NAT GW always requires an IGW to reach the internet.
- For IPv6, use an egress-only IGW instead of NAT.

---

## Appendix A: VPC Flow Logs

What they capture (metadata):

- Source/destination IPs and ports, protocol, direction, action (ACCEPT/REJECT), status (OK/NODATA/SKIPDATA), bytes/packets, timestamps, ENI.

What they do not capture:

- Packet payloads, application‑layer details (e.g., HTTP), or DNS transactions (use Route 53 Resolver query logs for DNS).

Common use cases:

- Troubleshooting connectivity, security monitoring/detection, compliance, traffic analytics and dashboards.

Destinations:

- CloudWatch Logs or S3. In this repo’s VPC lab, logs default to CloudWatch when enabled via `var.enable_flow_logs`.

---

## Appendix B: Subnet CIDR Indexing with `cidrsubnet`

Deterministic carving:

- `cidrsubnet(prefix, newbits, netnum)` divides a parent CIDR into equal child blocks. For /20 subnets from a /16, use `newbits = 4` producing 16 slots; pick `netnum` per subnet.

Why indices over hard‑coded CIDRs:

- Survives parent CIDR changes and AZ additions, avoids overlap mistakes, and keeps AZ↔CIDR intent explicit.

Pattern used in labs:

- Public indices `{ a=0, b=1 }`; Private `{ a=2, b=3 }`. Reserve `[0..N-1]` for public and `[N..2N-1]` for private (N = number of AZs).

CIDR sizing and math refresher:

- A VPC `/16` has 65,536 IPv4 addresses. A `/20` has 4,096. Setting `newbits = 4` splits a `/16` into 16 `/20`s. Indices `0..15` pick which block.
- Example mapping for `10.64.0.0/16` with `/20` children:
  - 0 → `10.64.0.0/20`, 1 → `10.64.16.0/20`, 2 → `10.64.32.0/20`, 3 → `10.64.48.0/20`, …

Choosing sizes (guidance):

- Start with VPC `/16` unless you have strict constraints. Subnets commonly `/20` or `/21` for app tiers; `/24`–`/26` for DB subnets.
- Account for AWS reserving 5 IPs per subnet. Smaller subnets feel this more.

Common patterns:

- 2 AZ staging: 2 public + 2 private `/20`; single NAT (cost‑saver).
- 3 AZ production: 3 public + 3 private `/21` or `/20`; NAT per AZ; per‑AZ private route tables.
- Add DB subnets without default route to IGW/NAT; attach RDS/Redis there.

Gotchas:

- Cross‑AZ NAT hairpin costs; prefer NAT per AZ in prod.
- Main route table defaults can surprise—explicitly associate all subnets.
- EKS/ECS IP consumption can exhaust small subnets; size with headroom.

---

### Full /16 → /20 index table (example `10.64.0.0/16`)

| netnum | /20 CIDR       |
| ------ | -------------- |
| 0      | 10.64.0.0/20   |
| 1      | 10.64.16.0/20  |
| 2      | 10.64.32.0/20  |
| 3      | 10.64.48.0/20  |
| 4      | 10.64.64.0/20  |
| 5      | 10.64.80.0/20  |
| 6      | 10.64.96.0/20  |
| 7      | 10.64.112.0/20 |
| 8      | 10.64.128.0/20 |
| 9      | 10.64.144.0/20 |
| 10     | 10.64.160.0/20 |
| 11     | 10.64.176.0/20 |
| 12     | 10.64.192.0/20 |
| 13     | 10.64.208.0/20 |
| 14     | 10.64.224.0/20 |
| 15     | 10.64.240.0/20 |

Recipe to reproduce for any sizes:

1. Choose parent `/P` and child `/C`. Compute `newbits = C − P` and slots = `2^newbits`.
2. Decide AZ count `N` and tiers (public/private/DB/etc.).
3. Assign index ranges per tier: `[0..N-1]` public, `[N..2N-1]` private, `[2N..3N-1]` DB.
4. Implement with `cidrsubnet(prefix, newbits, netnum)` using per‑AZ maps.
5. Validate no overlaps and correct routing per tier.

This layered model supports least privilege, scalability, and cost optimisation.

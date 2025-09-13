# Apply Config Order

What: Suggested order for pasting/applying configs in the Packet Tracer campus lab.
Why: Reduces churn and avoids early loops or DHCP/NAT surprises.
When: First bring-up or after a full reset.
How: Stage configs and verify at each point.

Order

1. Distribution Switch A (root) — `dist-a.cfg`
   - Create VLANs 10/20, trunks, set Rapid-PVST and root priority.
2. Distribution Switch B (secondary) — `dist-b.cfg`
   - Mirror VLANs/trunks, set secondary priority.
3. Access Switch — `access-1.cfg`
   - Trunk uplink to Dist A; configure access ports with PortFast/BPDU Guard, storm-control, port-security.
4. Edge Router — `edge-router.cfg`
   - Subinterfaces, gateways, DHCP pools, NAT overload, DNAT for HTTPS.
5. Extras — `extras.cfg`
   - Errdisable recovery, logging stamps, LLDP.
6. Verify
   - Use `scripts/verify-commands.md` and the README’s verification section.

Notes

- Hairpin NAT in IOS varies by platform; prefer split DNS for internal access to the on‑prem hostname.
- If WAN is PPPoE, set MSS adjust and mark the dialer as `ip nat outside`.

# Verify Commands (IOS)

What: Quick checklist of show/verify commands for the campus lab.
Why: Consistent validation shortens troubleshooting.
When: After initial config and after any changes.
How: Run on the noted device.

Edge Router (NAT/DHCP)

```
show ip interface brief
show ip route | inc ^S|^Gateway|0.0.0.0
show ip nat translations
show ip nat statistics
show ip dhcp binding
show ip dhcp pool
```

Distribution/Access (L2/L3)

```
show vlan brief
show interfaces trunk
show spanning-tree vlan 10
show spanning-tree vlan 20
show spanning-tree interface status
show port-security interface gi0/2
show storm-control broadcast
show errdisable recovery
```

End-to-end tests

- From H1: ping default gateway 10.10.10.1, browse outbound (if Internet present)
- From outside (simulated): curl/HTTPS to Edge WAN and reach SVC via DNAT (hairpin internal access uses split DNS)

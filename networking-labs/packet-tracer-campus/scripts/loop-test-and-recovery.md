# Loop Test and Recovery (BPDU Guard)

What: Safely test loop detection and automatic recovery.
Why: Validates that PortFast/BPDU Guard protects the campus from unmanaged switch loops.
When: After initial STP/edge hardening is configured on access ports.
How: Temporarily connect two access ports on the same switch; observe err-disable.

Steps

1. Ensure access ports have:
   - `spanning-tree portfast`
   - `spanning-tree bpduguard enable`
   - Optional: `storm-control broadcast level 1.00 0.50`
2. Patch a short cable between Gi0/2 and Gi0/4 on ACCESS-1.
3. Observe:
   - `show spanning-tree interface status`
   - `show errdisable recovery`
   - One or both ports go err-disabled on BPDU receive.
4. Remove the loop cable.
5. Recover the port(s):
   - `shutdown` then `no shutdown` on the interface OR wait for errdisable recovery if configured.
6. Verify hosts can pass traffic again.

CLI snippets

```
conf t
 interface range gi0/2 , gi0/4
  spanning-tree portfast
  spanning-tree bpduguard enable
  storm-control broadcast level 1.00 0.50
 end
!
show spanning-tree interface status
show logging | inc BPDU|ERRDISABLE
```

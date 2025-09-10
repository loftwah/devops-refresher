# Route 53 DNS (Subdomain Delegation)

## Objective

Establish DNS for lab resources under a delegated subdomain, e.g., `aws.deanlofts.xyz`, and create records for ALB/ECS/EKS services.

## Decisions

- Use a dedicated public hosted zone: `aws.deanlofts.xyz`.
- Delegate from your parent zone (`deanlofts.xyz`) to Route 53 by adding NS records in the parent’s DNS.
- Records pattern: `app.aws.deanlofts.xyz`, `api.aws.deanlofts.xyz`.

## Tasks

1. Create `aws_route53_zone` for `aws.deanlofts.xyz` (public).
2. Output the zone’s NS records; add them as NS entries for `aws` in `deanlofts.xyz` (at your registrar or parent zone).
3. Create A/AAAA alias records pointing to ALB for ECS apps.
4. (Later, with EKS) Install external-dns to manage records from Ingress resources.

## Acceptance Criteria

- `dig +short app.aws.deanlofts.xyz` resolves to your ALB.
- The subdomain NS delegation is active (queries resolve consistently).

## Terraform Hints

- `aws_route53_zone`, `aws_route53_record` (A/AAAA alias to `aws_lb` DNS name).
- Use outputs to surface `zone_id` and `name_servers`.

## ClickOps Path (Recommended for Delegation with Cloudflare)

If your apex domain (`deanlofts.xyz`) is on Cloudflare, it’s simplest to delegate the `aws` subdomain via the consoles.

1. In AWS Console (Route 53)

- Hosted zones → Create hosted zone
- Name: `aws.deanlofts.xyz`
- Type: Public hosted zone
- After creation, open the zone and copy the 4 NS values from the pre‑created NS record.

Example (your current Route 53 NS set)

- ns-136.awsdns-17.com.
- ns-1412.awsdns-48.org.
- ns-1623.awsdns-10.co.uk.
- ns-630.awsdns-14.net.

2. In Cloudflare (for `deanlofts.xyz`)

- DNS → Add record
- Type: `NS`
- Name: `aws`
- Content: paste the 4 Route 53 NS values (one record each)
- Proxy status: DNS only (not proxied)
- TTL: Auto (or low TTL while testing)

Notes for Cloudflare entry

- Type: `NS`
- Name: `aws`
- Value: enter each nameserver as a separate NS record. Cloudflare accepts values without the trailing dot (e.g., `ns-630.awsdns-14.net`) and will normalize them.

3. Verify delegation

- `dig NS aws.deanlofts.xyz @1.1.1.1`
- `dig +trace aws.deanlofts.xyz`
- Expect the Route 53 NS set to appear. Propagation can take 5–30 minutes.

Notes

- Do not change the registrar NS for `deanlofts.xyz`. Only add NS records for the `aws` subdomain in Cloudflare.
- Once delegated, any records you create in the Route 53 zone `aws.deanlofts.xyz` resolve publicly (e.g., `demo-node-app-ecs.aws.deanlofts.xyz`).
- Add exactly four NS records with Name `aws` and the Route 53 nameserver values (e.g., `ns-136.awsdns-17.com.` `ns-1412.awsdns-48.org.` `ns-1623.awsdns-10.co.uk.` `ns-630.awsdns-14.net.`). Keep trailing dots or let Cloudflare normalize.
- Do not create conflicting records for `aws` in Cloudflare (no A/AAAA/CNAME at the `aws` label) — only the NS set.
- Leave Proxy status off (DNS only). Cloudflare cannot proxy NS records.
- DNSSEC: If enabled at the Cloudflare apex, that’s fine. Do NOT enable DNSSEC for the Route 53 subdomain unless you also add the DS record in Cloudflare. We do not enable DNSSEC for this subdomain in these labs.

Optional quick test

1. In Route 53 (child zone), add a temporary record:
   - Name: `whoami.aws.deanlofts.xyz`, Type: `TXT`, Value: `"r53-ok"`, TTL: 60
2. Check from a public resolver after a few minutes:
   - `dig +short TXT whoami.aws.deanlofts.xyz @1.1.1.1`
   - Expect: `"r53-ok"`

## Delegation Validator Script

Use `scripts/validate-delegation.sh` to check nameserver delegation and SOA:

```
scripts/validate-delegation.sh
```

By default it validates `aws.deanlofts.xyz` against your Route 53 nameserver set. Add `--verbose` to include a `dig +trace` summary, or override with `--domain`/`--expect-ns` if you ever change them.

Import to Terraform later (optional)

- If you created the hosted zone in the console but want Terraform to manage it:
- `terraform import aws_route53_zone.this Z1234567890ABC`

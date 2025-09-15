# SES Notes (Sandbox vs Production)

- Sandbox: new accounts/regions start in sandbox. You can only send to and from verified identities with low throughput. Request production access in the SES console to lift restrictions.
- DNS: verify domains with DKIM and SPF.
  - SPF: include `v=spf1 include:amazonses.com ~all` (or via your existing SPF record).
  - DKIM: add CNAMEs provided by SES; allow time for DNS propagation.
- Feedback: configure SNS topics for bounces and complaints; wire them to email or Slack.
- Regions: SES availability and sending limits vary by region; this repo uses `ap-southeast-2`.

Related labs: none (SES not a full lab in this refresher).

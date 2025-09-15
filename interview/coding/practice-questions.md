# Practice Questions (DevOps-flavoured)

Parsing and Metrics

1. Given an nginx access log stream, compute requests-per-minute per path and top-5 5xx endpoints over sliding 10 minutes.
2. Parse JSON build logs, detect flaky tests (fail→pass→fail), output a ranked list.

Pipelines and Idempotency 3) Write a script to create Git tags like vX.Y.Z only if changelog has an entry; print dry-run by default. 4) Implement exponential backoff with jitter for an HTTP call; cap retries; treat 5xx as retryable.

Kubernetes/Containers 5) Given `kubectl get pods -o json`, list pods CrashLoopBackOff > 5 restarts and output namespace/name + image. 6) Render a Helm-like template: replace {{VAR}} in YAML with env vars; error on missing.

AWS/IaC 7) Read Terraform state (local JSON) and print all AWS resources by type and count; flag drift if an expected type is missing. 8) Given a list of AMI IDs, validate they’re within last 30 days via `DescribeImages` response; print oldest.

Networking 9) Given pcap summary lines, detect spikes in TCP retransmits per source IP. 10) Implement a simple rate limiter (token bucket) for an API client.

Bonus 11) Write a tiny CLI: `ci-summary --file build.log` printing total tests, failures, duration, and top slow tests.

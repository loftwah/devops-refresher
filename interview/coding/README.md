# Coding Interviews for DevOps/SRE

Focus: practical problem solving in scripting, automation, and troubleshooting.

Languages: Python or Go preferred; Bash for glue; use what you’re strongest in.

Core Areas

- Data handling: parse logs/JSON/CSV; stream processing; regex
- Algorithms: maps/sets, sorting, sliding window, counters; Big-O intuition
- Systems: files, processes, sockets, HTTP, concurrency basics
- DevOps: CLI tools, API calls, retries/backoff, idempotency, resilience

Interview Flow

1. Clarify, restate, define inputs/outputs and edge cases
2. Start with a simple solution, then optimise; discuss trade-offs
3. Write tests or at least sample I/O checks
4. Explain time/space complexity in plain language

Practice With This Repo

- `demo-node-app/`: write a script to tag releases and trigger CI; parse build logs
- `networking-labs/`: build a small ping/trace parser and alert on anomalies
- `aws-labs/`: generate Terraform variable validation or a drift-checking script

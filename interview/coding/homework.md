# Coding Homework

1. Implement 2 problems from `practice-questions.md`

- Include a short README explaining approach and complexity

2. Write a log summariser

- Input: nginx access log file
- Output: CSV of timestamp minute, total reqs, 5xx count, top path

3. CI Utility for `demo-node-app/`

- Script: create release tag → trigger CI → poll for status → print summary
- Add retries with backoff on API calls

4. Kubernetes Triage

- Script: list pods with restarts>5; fetch last 20 log lines per pod

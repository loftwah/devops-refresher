# Loftwah's DevOps Refresher

## 1. Coding (LeetCode)

### How to Work

- For each problem solved:
  - Code solution in Ruby or Go
  - Add time and space complexity analysis
  - Write a short "pattern takeaway"
  - Store in `leetcode/<category>/<problem>.md`

### Arrays and Strings

- Two pointers: two-sum, three-sum, container with most water
- Sliding window: longest substring without repeats, minimum window substring
- Prefix sum: subarray sum equals k, maximum subarray
- Interval problems: merge intervals, insert interval

### Hashing

- Group anagrams
- Subarray sum problems
- LRU cache implementation

### Linked Lists

- Reverse a linked list
- Detect/remove cycle
- Merge two sorted lists
- Merge k sorted lists
- Copy list with random pointer

### Stacks and Queues

- Min stack
- Next greater element
- Largest rectangle in histogram
- Daily temperatures
- Valid parentheses

### Trees and Graphs

- DFS and BFS traversals
- Binary search tree validation
- Lowest common ancestor
- Level order traversal
- Serialize/deserialize binary tree
- Topological sort (course schedule)
- Shortest path: BFS and Dijkstra
- Union-Find: connected components, Kruskal MST

### Dynamic Programming

- Fibonacci variations
- Climbing stairs
- Coin change (min coins and combinations)
- Longest increasing subsequence
- Longest common subsequence
- Palindromic substrings
- Edit distance
- Word break
- Knapsack variations

### Sorting and Searching

- Binary search variations
- Search in rotated array
- Median of two sorted arrays
- Kth largest element (Quickselect/Heap)

### Advanced / High-Signal

- Implement Trie (prefix tree)
- Word search (backtracking)
- Regular expression matching (DP)
- Sudoku solver

---

## 2. System Design

### How to Work

- Each scenario gets a Markdown doc in `system-design/`
- Include:
  - Assumptions (traffic, scale, SLAs)
  - Architecture diagram (draw.io / Excalidraw / ASCII)
  - Component choices and tradeoffs
  - Risks and mitigations

### Core Concepts

- Load balancing: L4 vs L7
- Caching strategies: write-through, write-back, write-around, TTL
- Message queues: SQS, Kafka, RabbitMQ
- Database scaling: sharding, replication, indexing
- Storage design: object store, block storage, distributed file systems
- API design: REST, GraphQL, gRPC
- Authentication and authorisation
- TLS and certificate management
- Secrets management

### Practice Scenarios

- URL shortener
- Twitter feed / Facebook news feed
- WhatsApp / Slack real-time messaging
- YouTube / Netflix video streaming with CDN
- Rate limiter (token bucket, leaky bucket)
- Search autocomplete
- Payment system (idempotency, retries, consistency)
- Metrics and monitoring pipeline
- CI/CD pipeline design at scale

### Tradeoffs

- CAP theorem: consistency vs availability
- Strong vs eventual consistency
- SQL vs NoSQL
- Push vs pull models
- Batching vs streaming

---

## 3. AWS and DevOps Labs

### How to Work

- Each lab in `aws-labs/<lab-name>/`
- Deliverables:
  - `README.md` with Objective, Steps, Expected Outcome, Cleanup
  - Terraform or CloudFormation templates
  - Screenshots or CLI outputs proving success
  - Notes on what failed or broke

### Compute Labs

- EC2: launch templates + autoscaling groups, serve a web app behind ALB and then NLB
- ECS Fargate: deploy a containerised app behind ALB, scale, observe CloudWatch logs
- ECS EC2 + capacity providers: run same app with EC2 hosts and test scaling
- EKS: deploy app with Deployment, Service, Ingress, HPA
- Lambda: event triggers from S3, API Gateway, DynamoDB streams
- Step Functions: orchestrate Lambda workflow

### Networking and Security Labs

- VPC: custom VPC with public/private subnets, NAT, IGW
- Security groups vs NACLs: block/allow traffic and test
- PrivateLink, VPC peering, Transit Gateway connectivity
- IAM: policies, roles, permission boundaries
- KMS: encrypt/decrypt flow
- Secrets Manager vs SSM Parameter Store

### Storage and Database Labs

- S3: versioning, lifecycle rules, signed URLs, replication
- RDS: multi-AZ failover, read replicas
- DynamoDB: GSIs, LSIs, streams
- ElastiCache: Redis failover drill

### Observability Labs

- CloudWatch: logs, metrics, dashboards, alarms
- CloudTrail: track IAM events
- X-Ray: trace Lambda or API Gateway app

### CI/CD and Infra Labs

- CodeBuild + CodePipeline: ECS Fargate deploy pipeline
- GitHub Actions → EKS deploy with kubectl/Helm
- Blue/green and canary deployment demos
- Terraform basics for each of the above

---

## 4. Demo Applications

### Deliverables

- Each demo is a directory in `aws-labs/demo-apps/`
- Includes `README.md`, Terraform, Dockerfile, and app code

1. Rails or Go API → ECS Fargate

   - Push image to ECR
   - Deploy service behind ALB
   - AutoScaling and CloudWatch alarms
   - CI/CD with CodePipeline

2. Same app → EKS

   - Deployment, Service, Ingress
   - ConfigMaps and Secrets
   - HPA for autoscaling
   - Monitoring with Prometheus/Grafana

3. Extend app with RDS + ElastiCache

   - Connect to Postgres and Redis
   - Failover testing

4. CI/CD for ECS and EKS

   - ECS via CodePipeline
   - EKS via GitHub Actions
   - Blue/green and canary demos

5. Monitoring and Security
   - CloudWatch dashboards
   - SNS alerts
   - KMS encryption for data
   - Secrets Manager rotation

---

## 5. Extras

### Linux and Networking

Deliverables: notes and test commands

- netstat, lsof, tcpdump, strace
- Debugging CPU, memory, IO issues

### Git

Deliverables: Git repo with branches demonstrating each

- Rebase, cherry-pick, bisect
- Submodules, hooks

### Resilience and Operations

Deliverables: markdown writeups of what happened

- Chaos testing: kill pods or instances
- DR strategy document
- Backup and restore workflow test

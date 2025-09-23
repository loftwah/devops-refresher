# Heaps & Priority Queues Pattern Hub

Heaps solve “give me the smallest/largest/top-K right now” problems with logarithmic updates. In DevOps, that’s autoscaling, job scheduling, and prioritising alerts.

## Core Techniques

- **Binary Heap Basics**: push/pop in `O(log n)`.
- **Top-K Selection**: Maintain a heap of size K to track highest or lowest metrics.
- **Heap + Hash Map**: Combine for streaming frequency or task scheduling.

## Target Problems

- Kth Largest Element in an Array
- Merge K Sorted Lists (min-heap of list heads)
- Task Scheduler (max-heap with cooldown tracking)
- Top K Frequent Elements (min-heap or bucket sort)
- Find Median from Data Stream (two-heaps)

## DevOps Parallels

- Keeping top resource-consuming workloads on a dashboard.
- Prioritising incident remediation tasks by severity.
- Scheduling batch jobs based on next earliest deadline.

> Use this directory for heap-centric walkthroughs; integrate mini benchmarks when helpful.

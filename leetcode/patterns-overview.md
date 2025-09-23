# LeetCode Patterns Overview

Use this index to decide which problem set to study next. Each pattern includes the mindset, common interview prompts, and DevOps-flavoured use cases so you can anchor the algorithm to real infrastructure work.

## Arrays & Strings

- **Hash Map Lookup**: Two Sum, Subarray Sum Equals K, Anagram Groups. Mirrors log correlation or matching request/response IDs.
- **Two Pointers**: Container With Most Water, Three Sum, Merge Sorted Array. Think sliding resource windows or pairing metrics in SLO analysis.
- **Sliding Window**: Longest Substring Without Repeating Characters, Minimum Window Substring, Max Consecutive Ones. Similar to rate-limiting windows or rolling averages in monitoring.

## Linked Lists

- **Fast/Slow Pointers**: Linked List Cycle, Middle of Linked List. Relates to detecting feedback loops in pipelines.
- **In-Place Reversal**: Reverse Linked List, Reorder List. Analogy: re-flipping deployment orders.

## Stacks & Queues

- **Monotonic Stack**: Daily Temperatures, Next Greater Element. Same thinking as scaling decisions based on a monotonic metric.
- **Stack Simulation**: Valid Parentheses, Min Stack. Maps to maintaining state in IaC plan/apply cycles.
- **Queue + BFS**: Binary Tree Level Order Traversal, Flood Fill. Similar to breadth-first incident blast-radius checks.

## Trees & Graphs

- **Depth-First Search (DFS)**: Path Sum, Number of Islands, Clone Graph. Used in dependency tracing and security group reachability.
- **Breadth-First Search (BFS)**: Shortest Path in Binary Matrix, Word Ladder. Mirrors network hop analysis.
- **Binary Search Tree Ops**: Validate BST, Lowest Common Ancestor. Analogous to hierarchical IAM policies.

## Heaps & Priority Queues

- **Top-K / Stream Processing**: Kth Largest Element, Task Scheduler, Merge K Sorted Lists. Think job queues and autoscaling priorities.

## Binary Search

- **Classic Binary Search**: Search in Rotated Array, Find Minimum in Rotated Array. Maps to pinpointing regression windows or canary timeouts.
- **Binary Search on Answer**: Koko Eating Bananas, Minimize Max Distance to Gas Station. Similar to capacity planning with objective constraints.

## Dynamic Programming

- **1D DP (Linear)**: Climbing Stairs, House Robber, Maximum Subarray. Equivalent to cost or risk propagation along time series.
- **2D DP (Grid/Matrix)**: Unique Paths, Coin Change, Edit Distance. Resembles pipeline state transitions across environments.
- **State Compression**: Word Break, Subset Sum. Think feature flag combinations or Terraform plan diffs.

## Backtracking

- **Permutations & Combinations**: Permute, Combination Sum, Subsets. Similar to exploring infrastructure permutations in design reviews.
- **Constraint Satisfaction**: N-Queens, Sudoku Solver. Mirrors allocation problems in cluster schedulers.

## Graph Advanced

- **Union-Find (Disjoint Set)**: Number of Connected Components, Redundant Connection. Applicable to VPC peering or multi-account mapping.
- **Topological Sort**: Course Schedule, Alien Dictionary. Same as deploying Terraform modules respecting dependencies.
- **Dijkstra / Weighted Shortest Path**: Network Delay Time, Cheapest Flights Within K Stops. Matches routing or data transfer optimisation.

## Greedy

- **Interval Scheduling**: Merge Intervals, Non-overlapping Intervals. Analogous to maintenance windows and deployment waves.
- **Greedy Choice / Sorting**: Jump Game, Gas Station. Relates to cost-efficient scaling decisions.

---

For each pattern:

1. Copy `templates/problem-guide.md` to the relevant folder.
2. Fill out the story in Python first.
3. Add DevOps analogies so NotebookLM can weave audio narratives easily.
4. Cross-link problems using this index for spaced repetition.

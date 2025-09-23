# Problem Guide Template

> Duplicate this outline for each LeetCode-style walkthrough. Fill in the sections deliberately and trim anything that is not relevant.

## Problem Snapshot

- **Title**: _Problem name_
- **Source Link**: _https://leetcode.com/..._
- **Category / Pattern**: _e.g., Hash Map, Two Pointers_
- **Difficulty**: _Easy / Medium / Hard_

## What (Problem Definition)

- Restate the problem in plain language.
- Summarize the inputs, expected outputs, and notable constraints (size limits, value ranges, sorted vs unsorted, etc.).

## Why (Pattern & Intuition)

- Explain the algorithmic pattern the problem exercises.
- Compare the brute-force baseline with the optimized approach and call out the tipping point where the optimized pattern wins.
- Highlight any gotchas (duplicate values, negative numbers, overflow, in-place mutation).

## Where (DevOps & Real-Life Tie-In)

- Describe 1–2 DevOps scenarios where the same pattern shows up (e.g., log correlation, autoscaling heuristics, scheduling).
- Mention tools or AWS services that echo the same thinking.

## When (Signals to Reach for This Pattern)

- List features in the inputs or requirements that should make you consider this algorithm during an interview or in production work.

## How (Walkthrough)

1. Outline the step-by-step approach.
2. Provide a small example and walk through the state changes.
3. Note edge cases and how the algorithm handles them.

## Python Implementation

```python
from typing import List

class Solution:
    def solve(self, ...):
        ...
```

- Explain the critical lines after the snippet (why a hash map, pointer movement rules, etc.).
- State the time and space complexity with justification for each term.

### Test Bench

| Case       | Input | Expected Output | Notes |
| ---------- | ----- | --------------- | ----- |
| happy path |       |                 |       |
| edge       |       |                 |       |
| failure    |       |                 |       |

> Add a simple `pytest` or inline `assert` harness when useful. Capture failing examples if they demonstrate the limits of the chosen approach.

## Pattern Takeaways

- Bullet list of lessons learned or reminders for the next similar question.
- Link back to related problems in this repo once we have them.

## Follow-Up Ideas

- Notes on extending the solution (different language, handle streaming data, distributed variant, etc.).
- Questions an interviewer might ask next and how you would respond.

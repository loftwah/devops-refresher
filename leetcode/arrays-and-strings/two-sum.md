# Two Sum Walkthrough

## Problem Snapshot

- **Title**: Two Sum
- **Source Link**: https://leetcode.com/problems/two-sum/
- **Category / Pattern**: Hash Map, Single Pass Scan
- **Difficulty**: Easy

## What (Problem Definition)

Given an array `nums` of integers and an integer `target`, return the indices of the two numbers that add up to `target`. The array is 0-indexed, each input has exactly one valid answer, and the same element may not be used twice. Input length ranges from 2 to 10^4 and values can be negative or positive.

## Why (Pattern & Intuition)

The brute-force approach checks every pair of numbers (`O(n^2)`) which is painful once `n` grows beyond a few hundred. The optimized pattern trades memory for speed by storing numbers we have seen in a hash map (`value -> index`). For each new element `x`, we ask “have we already seen `target - x`?” If yes, we found the pair. Hash map lookups average `O(1)`, so the whole scan is `O(n)`.

Key gotchas:

- Duplicate values: the map must always hold the earliest index for a value unless the duplicate is needed for the answer.
- Negative numbers: subtraction still works, so nothing special is required.
- Exactly one answer guaranteed: we can return immediately once it is found.

## Where (DevOps & Real-Life Tie-In)

- **Alert correlation**: matching CPU and memory spikes that combine to breach an SLA threshold can mirror the “two numbers to hit a target” mindset.
- **Cost anomaly detection**: pairing AWS cost categories (e.g., EC2 + data transfer) that together exceed budget triggers.
- **Log aggregation**: when correlating request + response entries, hashing on `request_id` is identical to using the look-up table in this algorithm.

## When (Signals to Reach for This Pattern)

- Inputs arrive as an unsorted list, and you need to combine exactly two values to hit a target expression.
- You are allowed `O(n)` extra space (hash map) to beat quadratic time.
- Only one valid pair is promised, so early exit is safe.

## How (Walkthrough)

1. Initialise an empty dictionary `seen` to map value -> index.
2. Iterate through the list with `enumerate` to get both index `i` and value `num`.
3. Compute the complement `needed = target - num`.
4. If `needed` exists in `seen`, return `[seen[needed], i]`.
5. Otherwise, store the current value: `seen[num] = i`.
6. Continue until the answer is found (guaranteed before the loop ends).

Example (`nums = [2, 7, 11, 15]`, `target = 9`):

- i=0, num=2 → needed=7 → not in map → store `{2: 0}`.
- i=1, num=7 → needed=2 → found in map → return `[0, 1]`.

Edge cases:

- Minimal length array `[1, 3]`, `target=4` → returns `[0, 1]` immediately.
- Negative numbers `[-3, 4, 3, 90]`, `target=0` → complement logic still works.
- Duplicates `[3, 3]`, `target=6` → ensure we add the first 3 before checking the second.

## Python Implementation

```python
from typing import List

class Solution:
    def twoSum(self, nums: List[int], target: int) -> List[int]:
        seen: dict[int, int] = {}
        for index, value in enumerate(nums):
            needed = target - value
            if needed in seen:
                return [seen[needed], index]
            seen[value] = index
        raise ValueError("No solution found")
```

- The dictionary `seen` captures previously scanned values. The complement check happens before inserting the current value so we do not match an element with itself.
- Time complexity: `O(n)` because each value is processed once with constant-time dictionary operations.
- Space complexity: up to `O(n)` in the worst case when no pair is found until the end of the array.

### Test Bench

| Case             | Input                         | Expected Output | Notes                                     |
| ---------------- | ----------------------------- | --------------- | ----------------------------------------- |
| happy path       | `nums=[2,7,11,15], target=9`  | `[0,1]`         | Classic example from LeetCode             |
| duplicate values | `nums=[3,3], target=6`        | `[0,1]`         | Ensures we do not reuse the same index    |
| negatives        | `nums=[-3,4,3,90], target=0`  | `[0,2]`         | Validates complement works with negatives |
| late match       | `nums=[5,1,4,2,8], target=10` | `[1,4]`         | Confirms we store indices until the end   |

Quick inline test harness:

```python
if __name__ == "__main__":
    solver = Solution()
    assert solver.twoSum([2, 7, 11, 15], 9) == [0, 1]
    assert solver.twoSum([3, 3], 6) == [0, 1]
    assert solver.twoSum([-3, 4, 3, 90], 0) == [0, 2]
    assert solver.twoSum([5, 1, 4, 2, 8], 10) == [1, 4]
    print("All tests passed.")
```

## Pattern Takeaways

- Hash maps are the go-to tool whenever you need near-instant lookups of previously seen data.
- Doing the complement check before inserting the current value prevents self-pairing.
- Early return keeps the implementation clean when a solution is guaranteed.

## Follow-Up Ideas

- Implement the same logic in Go, Ruby, and TypeScript to compare syntax and standard-library support once the Python version feels natural.
- Discuss how the approach scales when the data stream is unbounded (hint: sliding window or streaming joins).
- Explore related problems: Two Sum II (sorted array), Two Sum III (data structure design), and 3Sum to extend the pattern playbook.

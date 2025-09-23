# Container With Most Water Walkthrough

## Problem Snapshot

- **Title**: Container With Most Water
- **Source Link**: https://leetcode.com/problems/container-with-most-water/
- **Category / Pattern**: Two Pointers, Greedy Shrink
- **Difficulty**: Medium

## What (Problem Definition)

You are given an integer array `height` where each element represents the height of a vertical line drawn on the x-axis at that index. Choose two lines such that the container formed with the x-axis holds the maximum amount of water. Return this maximum area. The array length can be up to 10^5 and heights up to 10^4. The width between lines is simply the number of index steps between them.

Picture a sample input:

```
height = [1, 8, 6, 2, 5, 4, 8, 3, 7]
index  =  0  1  2  3  4  5  6  7  8
```

If we draw each height with `#` characters, we can “see” the walls:

```
0: #
1: ########
2: ######
3: ##
4: #####
5: ####
6: ########
7: ###
8: #######
```

We want to pick two of these vertical walls plus the ground (x-axis) to hold the most water.

## Why (Pattern & Intuition)

Checking every possible pair of walls means nested loops and `O(n^2)` work—too slow when `n` is big. We can do better by noticing two simple facts:

1. The amount of water between two walls = (shorter wall height) × (distance between walls).
2. To get a bigger area, we would like both “shorter wall height” and “distance” to be large.

Start with the widest container: the first wall (index 0) and the last wall (index `n-1`). Multiply the shorter height (here, 1) by the width (8) to get the area (8). If we want a bigger area next time, we must try to find a taller wall while keeping as much width as we can. The only move that can possibly help is to slide the pointer that currently points at the shorter wall. Sliding the taller wall would only reduce width while keeping the same limiting height.

So the rule is: keep the two pointers on the edges, measure the area, then move the pointer at the smaller wall inward and repeat. That greedy move gives us a chance to see a taller wall without wasting more width than necessary.

Common pitfalls:

- Forgetting that equal heights still allow either pointer to move; moving the left or right pointer works, but stay consistent.
- Overflow is not a concern in Python, but in other languages the area may exceed 32-bit integer bounds.
- The optimal pair may be adjacent lines; ensure the loop checks every width as pointers converge.

## Where (DevOps & Real-Life Tie-In)

- **Throughput vs latency trade-off**: Balancing two constraints (height and width) mirrors tuning autoscaling policies where the smallest capacity metric dictates throughput.
- **Network bandwidth planning**: Combining link capacity (height) with distance or hop count (width) to maximise effective throughput.
- **S3 lifecycle cost optimisation**: Choosing two boundaries (e.g., storage class vs. retention length) to maximise savings resembles exploring pairs that maximise a combined value.

## When (Signals to Reach for This Pattern)

- You need to optimise a value that depends on two indices and is bounded by the smaller of two values.
- The input is sorted by position (implicit index order), not by value.
- Moving one boundary inward can only help if you replace the limiting factor with something better (here, a taller line).

## How (Walkthrough)

1. Set `left` to 0 and `right` to `len(height) - 1`.
2. Calculate the current area: `min(height[left], height[right]) * (right - left)`.
3. Update `max_area` if the current area is larger.
4. Move the pointer at the shorter line inward (`left += 1` if `height[left] <= height[right]`, else `right -= 1`).
5. Repeat until `left` meets `right`.

### Step-by-Step Example

We will work through `height = [1, 8, 6, 2, 5, 4, 8, 3, 7]` and track the math each time.

| Step | left | right | height[left] | height[right] | width (`right-left`) | min height | area (`min * width`) | best so far |
| ---- | ---- | ----- | ------------ | ------------- | -------------------- | ---------- | -------------------- | ----------- |
| 1    | 0    | 8     | 1            | 7             | 8                    | 1          | 1 × 8 = **8**        | 8           |
| 2    | 1    | 8     | 8            | 7             | 7                    | 7          | 7 × 7 = **49**       | 49          |
| 3    | 1    | 7     | 8            | 3             | 6                    | 3          | 3 × 6 = **18**       | 49          |
| 4    | 1    | 6     | 8            | 8             | 5                    | 8          | 8 × 5 = **40**       | 49          |
| 5    | 1    | 5     | 8            | 4             | 4                    | 4          | 4 × 4 = **16**       | 49          |
| 6    | 1    | 4     | 8            | 5             | 3                    | 5          | 5 × 3 = **15**       | 49          |
| 7    | 1    | 3     | 8            | 2             | 2                    | 2          | 2 × 2 = **4**        | 49          |
| 8    | 1    | 2     | 8            | 6             | 1                    | 6          | 6 × 1 = **6**        | 49          |

Pointer movement explained:

- Step 1 → 2: left wall (height 1) is shorter, so move `left` to index 1.
- Step 2 → 3: right wall (height 7) is shorter, so move `right` to index 7.
- Keep following the rule: always move the pointer at the shorter wall.

By the time the pointers meet, the best area we saw was `49`, which comes from walls at indices 1 and 8 (heights 8 and 7) with width 7.

Edge considerations:

- All heights equal: `height = [5,5,5,5]` results in `max_area = 5 * (n - 1)`.
- Strictly increasing heights: best container may be between a middle and far-right index.
- Arrays of size 2: return `min(height[0], height[1])` immediately.

## Python Implementation

```python
from typing import List

class Solution:
    def maxArea(self, height: List[int]) -> int:
        left, right = 0, len(height) - 1
        max_area = 0

        while left < right:
            width = right - left
            h = min(height[left], height[right])
            max_area = max(max_area, h * width)

            if height[left] <= height[right]:
                left += 1
            else:
                right -= 1

        return max_area
```

- The loop runs at most `n - 1` times, making time complexity `O(n)`.
- Space complexity stays `O(1)` because only pointers and simple variables are stored.

### Test Bench

| Case       | Input                        | Expected Output | Notes                             |
| ---------- | ---------------------------- | --------------- | --------------------------------- |
| happy path | `height=[1,8,6,2,5,4,8,3,7]` | `49`            | Best area between indices 1 and 8 |
| flat       | `height=[5,5,5,5]`           | `15`            | Any two lines yield same area     |
| decreasing | `height=[6,5,4,3,2,1]`       | `12`            | Optimal near the left edge        |
| minimal    | `height=[1,1]`               | `1`             | Smallest valid input              |

Example inline runner:

```python
if __name__ == "__main__":
    solver = Solution()
    assert solver.maxArea([1, 8, 6, 2, 5, 4, 8, 3, 7]) == 49
    assert solver.maxArea([5, 5, 5, 5]) == 15
    assert solver.maxArea([6, 5, 4, 3, 2, 1]) == 12
    assert solver.maxArea([1, 1]) == 1
    print("All tests passed.")
```

## Pattern Takeaways

- When maximising with two moving boundaries, move the pointer that constrains the current value.
- Two-pointer techniques excel when the search space is ordered by position rather than value.
- Tracking the best candidate so far allows one-pass solutions even for large arrays.

## Follow-Up Ideas

- Compare with the `Trapping Rain Water` problem, which also balances boundaries but requires storing prefix/suffix maxima.
- Explore streaming variants: if heights arrive over time, can we maintain the best area with limited memory?
- Translate to Go/Ruby/TypeScript to reinforce the pointer mechanics in other languages.

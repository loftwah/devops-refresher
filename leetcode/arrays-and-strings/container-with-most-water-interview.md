# Container With Most Water — Interview Script

Use this script to rehearse the conversation. It captures how an interviewer might frame the problem, what clarifying questions to ask, how to narrate your reasoning, and where to weave in DevOps analogies.

---

### Round 1 — Problem Statement

**Interviewer:** “You are given an array of non-negative integers. Each number represents a vertical line on the x-axis. Choose two lines that, together with the x-axis, form a container that holds the most water. Return the maximum area. The indices represent positions on the x-axis. Can you talk me through a solution?”

**You:** “Sure. Just to confirm:

1. The array is 0-indexed, and the distance between two lines is simply the difference in their indices.
2. Heights can be zero, but not negative.
3. There’s no trick like tilting the container; we just use the lines as-is.
4. We only need the area, not the indices of the lines.
   Does that line up with your expectation?”

**Interviewer:** “Yes, that’s correct.”

---

### Round 2 — Baseline / Brute Force

**You:** “First, the brute-force idea is to test every pair of lines. For indices `i` and `j`, the area is `min(height[i], height[j]) * (j - i)`. That works but it is `O(n^2)` comparisons, which is slow for large input.”

**Interviewer:** “How big might `n` be?”

**You:** “If we assume up to 10^5 entries, `n^2` work is 10^10 checks—too slow. So we need something closer to linear time.”

---

### Round 3 — Main Idea

**You:** “Because the area depends on the shorter wall, I want to try a two-pointer strategy. Start with the widest container—the first and last index—calculate the area, and then move the pointer at the shorter wall inward. The reason to move the shorter one is that the area is limited by that height, so increasing the height is the only way to beat the current area, and moving the taller one would only shrink the width without improving the limiting height.”

**Interviewer:** “Can you walk me through an example?”

**You:** “Absolutely. Let’s take `height = [1, 8, 6, 2, 5, 4, 8, 3, 7]`. I’ll narrate every step aloud:

- Start with left=0 (height 1), right=8 (height 7). Width is 8, min height is 1 → area 8.
- The left wall is shorter, so move left to 1. Now left=1 (height 8), right=8 (height 7). Width is 7, min height is 7 → area 49.
- Update the best area to 49.
- Right wall is shorter now, so move right to 7 (height 3). Width is 6, min height 3 → area 18.
- Keep repeating until pointers meet. The best area we ever see is 49.”

**Interviewer:** “What’s the complexity?”

**You:** “Single pass, so `O(n)` time and `O(1)` extra space.”

---

### Round 4 — Edge Cases & Validation

**Interviewer:** “What edge cases do you think about?”

**You:**

- “If the array has only two elements, we just return the area between them—this algorithm covers that because the loop runs once.
- If heights are equal everywhere, moving either pointer works; we’ll still keep the best area.
- If one side is zero, the algorithm quickly moves past it because it’s the shorter side.”

**Interviewer:** “Would this work if the answer is formed by two adjacent lines?”

**You:** “Yes. The pointers eventually become adjacent (`right - left == 1`), so we check that width as well.”

---

### Round 5 — DevOps Analogy (Optional Talking Point)

**You:** “In day-to-day work, I see this pattern when balancing two limiting resources. For example, autoscaling: the available throughput is `min(cpu_capacity, memory_capacity) * number_of_instances`. If I want to improve overall throughput, I measure the wider picture, then relieve the tighter constraint first. It’s the same logic as moving the shorter wall.”

---

### Round 6 — Final Answer

**Interviewer:** “Can you summarise the algorithm?”

**You:** “Yes. Initialise two pointers at both ends, track the best area, and while `left < right`: calculate the area, update the best score, move whichever pointer points to the shorter wall, and continue. Return the best area. That gives us `O(n)` time and constant space.”

**Interviewer:** “Great, thanks.”

---

Use this script to rehearse aloud. Swap in other sample arrays and narrate the pointer moves to keep the reasoning fresh.

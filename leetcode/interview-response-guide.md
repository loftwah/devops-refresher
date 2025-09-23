# Algorithm Interview Response Guide

Use this playbook alongside each pattern primer. It gives you a reusable script so every answer sounds structured, confident, and grounded in real-world experience.

## 5-Step Answer Framework

1. **Clarify the Input**
   - Quote the data structure and its properties. Example: “We have an unsorted integer array; indices are 0-based.”
   - Ask about constraints: size bounds, negative values, duplicate entries, immutable strings.
   - Link to pattern primer: “Given this is an array/string, I’ll follow the approach from `arrays-and-strings/README.md`.”

2. **State the Baseline**
   - Describe the obvious but slow solution (`O(n^2)` double loop, storing all nodes, etc.).
   - Explain why it fails: “With 10^5 elements, the quadratic approach is too slow.”

3. **Announce the Pattern**
   - Name the technique (“two pointers”, “hash map lookup”, “fast/slow pointer”).
   - Summarise the key rule from the primer: “Move the pointer at the shorter wall because height limits area.”
   - Mention DevOps analogy: “It’s like correlating log start/end times without loading all records.”

4. **Narrate a Dry Run**
   - Pick a tiny example and walk through each step out loud.
   - For arrays/strings, call out indices, values, dictionary contents.
   - For linked lists, say the pointer positions (“slow at node 2, fast at node 4”).

5. **Close with Complexity & Edge Cases**
   - Quote time and space complexity.
   - List at least two edge cases from the primer checklist.
   - Offer optional follow-up: “I can extend this to handle streaming inputs if needed.”

## Example Mapping

| Pattern          | Go-to primer                   | Interview hook                                                                             |
| ---------------- | ------------------------------ | ------------------------------------------------------------------------------------------ |
| Arrays & Strings | `arrays-and-strings/README.md` | “This is a sliding window scenario—let me talk through the two pointers and window size.”  |
| Linked Lists     | `linked-lists/README.md`       | “I’ll use fast/slow pointers; here’s how the hare catches the tortoise if there’s a loop.” |

## Pre-Interview Drill

- Skim the relevant primer (arrays/strings or linked lists) before the call.
- Open a walkthrough document (e.g., `two-sum.md`) and practice narrating the dry run.
- Rehearse the interview script variant (e.g., `container-with-most-water-interview.md`).
- Keep a DevOps analogy ready—it differentiates you from purely academic answers.

## Post-Answer Checklist

After responding, silently confirm you covered:

- ❑ Clarifications
- ❑ Baseline
- ❑ Pattern name + why it fits
- ❑ Dry run with numbers
- ❑ Complexity + edge cases
- ❑ Optional real-world tie-in

If any box is missing, volunteer the info (“One more note on edge cases…”).

Keep this guide pinned next to the pattern folders. The more you repeat the framework, the faster you’ll deliver polished answers under pressure.

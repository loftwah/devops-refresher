# Arrays & Strings Primer

Use this guide before diving into individual problems. It explains what arrays and strings are, what questions interviewers probe, and how to talk through them during a conversation.

## What (Definitions in Plain English)

- **Array**: A box of slots side-by-side. Each slot holds a value. You can jump directly to any slot if you know its index (like jumping to row 42 in a spreadsheet). Indices start at 0 in Python.
- **String**: A sequence of characters stored like an array. You still access characters by index, but the values are letters or symbols instead of numbers.
- **Why they appear together**: Most string problems boil down to looking at characters as array entries. Same patterns (two pointers, sliding windows, hash maps) apply to both.

### Basic Operations

| Operation               | Array            | String                                              | Interview Sound Bite                                                               |
| ----------------------- | ---------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Access element by index | `nums[i]`        | `text[i]`                                           | "Indexing is `O(1)` because arrays are contiguous."                                |
| Modify element          | `nums[i] = 5`    | strings are immutable in Python; build a new string | "In Python, strings are immutable, so I convert to list if I need in-place edits." |
| Iterate                 | `for x in nums:` | `for ch in text:`                                   | "Linear scan, `O(n)` time."                                                        |
| Slice                   | `nums[l:r]`      | `text[l:r]`                                         | "Slicing makes a copy in Python; note the extra `O(k)` cost."                      |

## Why (Typical Interview Angles)

- **Pattern recognition**: Two pointers, sliding window, hashing, prefix sums.
- **Constraint handling**: Large input sizes, need for single pass, immutability of strings.
- **Edge discipline**: Empty arrays, repeated values, uppercase/lowercase handling, Unicode.
- **DevOps parallel**: Arrays/strings mirror logs, metrics, or config lines—fast scans and pattern matching are daily operations.

## When (Signals & Decision Tree)

1. **Need fast lookups of counts or positions?** Reach for a hash map (`dict`) to store counts or last-seen indices.
2. **Need to examine a contiguous chunk?** Consider sliding windows (grow/shrink pointers to maintain a condition).
3. **Need to compare two ends?** Two pointers meeting in the middle works well with sorted arrays or symmetrical checks (palindrome).
4. **Need to compute running totals?** Prefix sums or cumulative counts help answer range queries quickly.

### Examples in DevOps Terms

- **Sliding window**: Determine if CPU usage stayed above 80% for any 5 minute block (array of readings, maintain a window sum).
- **Hash map frequency**: Detect repeated log signatures by counting occurrences of each error message.
- **Two pointers**: Correlate start and end timestamps to find the longest stable deployment window without restarts.

## How (Walkthrough Template)

When you face an arrays/strings question in an interview, narrate these steps:

1. **Restate** the input/output clearly: “I get `nums` of length `n`… indices are 0-based.”
2. **Confirm constraints**: “Should I expect negative numbers? Do we care about multiple answers?”
3. **State baseline**: mention the brute force (`O(n^2)` double loop) so the interviewer sees you checked it.
4. **Introduce the pattern**: “Because we only need one pass and fast lookups, I’ll hold a dictionary of complements.”
5. **Dry run aloud**: pick a tiny example, say the indices and data each step.
6. **Complexity**: close with `O(n)` or `O(n log n)` and memory usage.
7. **Edge cases**: empty list, duplicates, negative numbers, uppercase vs lowercase.
8. **DevOps analogy (optional)**: connects the pattern to real-world experience, showing practical value.

## Sample Interview Exchange (Array -> Two Sum)

**Interviewer:** “Given `nums` and `target`, return the indices of the numbers that add up to `target`.”

**You:**

1. “To confirm, the array is unsorted, and there is exactly one answer? Can numbers repeat?”
2. “Naively I could try every pair, which is `O(n^2)` time—too slow for big arrays.”
3. “Instead, I’ll walk the array once, store each number’s index in a hash map, and check if `target - num` is already there.”
4. Dry run with `[2,7,11,15], target=9` while narrating the dictionary updates.
5. “Time is `O(n)`, space `O(n)` for the dictionary.”

## Cheat Sheet: Common Patterns in This Folder

- **Two Pointers**: Container With Most Water, 3Sum, Valid Palindrome.
- **Sliding Window**: Longest Substring Without Repeating Characters, Minimum Window Substring.
- **Counting / Hashing**: Two Sum, Group Anagrams, Top K Frequent Elements.
- **Prefix/Suffix**: Product of Array Except Self, Find Pivot Index.

Keep this file open while practicing. Every new walkthrough should link back to its pattern here so you can revisit the mental model quickly.

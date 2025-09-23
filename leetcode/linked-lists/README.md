# Linked Lists Primer

Linked lists look intimidating until you picture them as a chain of index cards. Each card (node) holds a value and a pointer to the next card. Interviewers love them because they reveal how confident you are with pointers, mutation, and reasoning about one node at a time.

## What (Definition & Visual)

```
value: 7  ──► value: 13  ──► value: 24  ──► None
         next           next           next
```

- **Head**: the first node in the chain.
- **Tail**: the node whose `next` pointer is `None`.
- **Singly linked list**: nodes only know about the `next` node.
- **Doubly linked list**: nodes store both `next` and `prev` pointers.

Key differences vs arrays:

- Access is sequential. To reach the 5th node you walk from the head (`O(n)` lookup).
- Insert or delete at the front is `O(1)`—just rewire pointers.
- Memory is scattered across the heap; each node is a separate allocation.

## Why (Interview Themes)

- **Pointer safety**: making sure you do not lose the rest of the list when swapping or deleting nodes.
- **Cycle detection**: catching infinite loops or verifying data structures.
- **In-place updates**: modify structure without extra arrays (important when memory is tight).
- **Streaming mindset**: operate on data as it arrives, one node at a time.

## When (Pattern Signals)

1. **Need to insert/remove frequently at the front or middle?** Linked lists shine because no shifting is required.
2. **Streaming data**: you cannot load the full array, so you keep a pointer that streams through nodes.
3. **Cycle or loop checks**: fast/slow pointer technique immediately applies.
4. **Reverse or reorder on the fly**: think reversing a path, merging two sorted event streams.

### DevOps Parallels

- **Incident timelines**: nodes represent events; reversing the list gives a forward chronology.
- **Pipeline DAG loops**: detect cycles just like `Linked List Cycle` to avoid infinite deploy loops.
- **Rolling logs**: merging sorted log files matches `Merge Two Sorted Lists`.

## Core Techniques

- **Fast/Slow Pointer (Floyd’s Tortoise and Hare)**: advance one pointer by one step, the other by two to detect cycles or find midpoints.
- **In-Place Reversal**: change `next` pointers as you walk; keep track of `prev`, `curr`, `next_node`.
- **Sentinel/Dummy Nodes**: prepend a fake head to simplify insert/delete logic near the front.
- **Two-List Merge**: maintain pointers to both lists and attach the smaller node each time (like merge step in merge sort).

## Example Walkthrough (Reverse Linked List)

Sample list: `1 -> 2 -> 3 -> None`

1. `prev = None`, `curr = 1`. Save `next_node = 2`, point `curr.next` to `prev` (None). Move `prev` to 1, `curr` to 2.
2. Repeat: save `next_node = 3`, point `2.next` to `prev` (1). Move pointers forward.
3. Continue until `curr` becomes `None`; `prev` now points to `3 -> 2 -> 1 -> None`.

Narrate this out loud during interviews to prove you control the pointer flow.

## Target Problems (Practice Order)

1. **Reverse Linked List** — pointer fundamentals.
2. **Middle of the Linked List** — fast/slow pointer intro.
3. **Linked List Cycle** — extend fast/slow to detect loops.
4. **Merge Two Sorted Lists** — merging streams.
5. **Reorder List / Reverse Nodes in k-Group** — advanced pointer juggling.

## Interview Script Snippet (Cycle Detection)

**Interviewer:** “Given a linked list, determine if it has a cycle.”

**You:**

1. Clarify: “Do we modify the list? Can we use extra memory?”
2. Baseline: “We could track visited nodes in a set (`O(n)` space).”
3. Optimized: “Use two pointers—`slow` moves one step, `fast` moves two. If they ever meet, there’s a cycle; if `fast` hits `None`, no cycle.”
4. Dry run with a 4-node list where the tail points back to the second node. Speak the pointer positions each step.
5. Complexity: `O(n)` time, `O(1)` extra space.

## Quick Reference Table

| Technique         | Best Use                    | Mental Model                                         |
| ----------------- | --------------------------- | ---------------------------------------------------- |
| Fast/Slow pointer | Cycle detection, midpoints  | Hare laps tortoise if there is a loop                |
| In-place reversal | Reverse or reorder segments | Always keep track of `next_node` before rewiring     |
| Dummy node        | Insert/delete near head     | Temporary head guards against null-pointer headaches |
| Merge two lists   | Combine sorted streams      | Like zipping two sorted log files                    |

Keep this primer open while working through linked-list problems. Link each new walkthrough back here so you revisit the fundamentals before diving into code.

> Copy `templates/problem-guide.md` into this folder when you start a new linked list walkthrough and reference the script snippets above during your explanation.

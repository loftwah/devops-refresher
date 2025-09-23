# Greedy Pattern Hub

Greedy algorithms make the locally optimal choice at each step, banking on a proof that this leads to a global optimum. In operations, this resembles picking the next best action when time is tight.

## Core Techniques

- **Interval Scheduling / Merging**: Sort intervals, then merge or select non-overlapping ones.
- **Greedy Jump / Reachability**: Maintain farthest reach while scanning.
- **Resource Allocation**: Always pick highest benefit per cost unit.

## Target Problems

- Merge Intervals / Insert Interval
- Non-overlapping Intervals / Meeting Rooms II
- Jump Game / Jump Game II
- Gas Station
- Partition Labels

## DevOps Parallels

- Scheduling deployments within maintenance windows.
- Choosing the next incident to resolve based on ROI.
- Allocating compute headroom across regions to prevent cascading failures.

> Document the selection logic clearly so NotebookLM can explain why each greedy move is justified.

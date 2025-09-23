# NotebookLM Prompt Playbook

These prompts are tuned for uploading `repomix-output.xml` (or any repo bundle) into NotebookLM. They steer the AI to teach through the material as an audio-first experience—ideal for deep-dive podcasts where the listener cannot see or manipulate the repo.

## Core Teaching Prompt

```
You are narrating an audio masterclass for someone who cannot see or type—they are learning entirely by listening. Use the attached repomix-output.xml to:
- Introduce the overall purpose of the repo in plain language.
- Move through each major section like a tour guide: describe folders, what problems they solve, and how they connect.
- For every code walkthrough, explain the problem, the intuition, the Python approach, and when to use it in DevOps work.
- Pause after big ideas to recap what the listener should remember, and suggest a mental exercise they can do without touching a computer.
- Avoid visual cues ("as you can see"). Rely on analogies, enumerated steps, and verbal summaries so the listener can follow along hands-free.
- Close with a checklist the listener can say out loud to self-test comprehension.
```

## Deep-Dive Module Prompt

Use this when you want NotebookLM to focus on a specific LeetCode write-up (e.g., `two-sum.md`).

```
Focus on the "Two Sum Walkthrough" section from the dataset. Create a 5-minute audio teaching script that covers:
1. Problem statement in conversational terms.
2. Why the hash map pattern wins over brute force.
3. A narrated dry run of the Python code (state the indices, values, and dictionary contents aloud).
4. Real-world DevOps parallels so the listener can connect it to their job.
5. Three self-quiz questions at the end.
Make sure the narration is friendly and paced for someone taking notes mentally.
```

## Compare-and-Contrast Prompt

```
Using the repo bundle, compare "Two Sum" and "Container With Most Water". Teach the listener:
- How the two-pointer mindset differs from the hash map mindset.
- When to favour each pattern in on-call troubleshooting or AWS cost analysis.
- Common mistakes interview candidates make with each problem.
Present it as a dialogue between two mentors so the listener hears both perspectives.
```

## Follow-Up Coaching Prompt

```
Generate a follow-up coaching session that assumes the listener just heard the main walkthrough. Reinforce retention by:
- Asking them to mentally walk through a new example.
- Guiding them through a spaced-repetition recap: "Remind me what the complement means..." etc.
- Suggesting next steps (e.g., "Tomorrow, try narrating the algorithm back and compare with this transcript").
Keep the tone encouraging and audio-friendly.
```

> Tip: When you assemble the repo with Repomix, set the format to XML/Markdown for cleaner chunking. NotebookLM handles medium-length files best, so exclude binary assets.

## Pattern Overview Prompt

```
Using the repo bundle, locate `leetcode/patterns-overview.md` and produce an audio lecture that:
- Summarises each pattern category in plain language.
- Gives a DevOps-flavoured scenario for the pattern so the listener can picture applying it on-call.
- Recommends 1–2 flagship problems per pattern and tells the listener what mindset to adopt before attempting them.
- Ends with a spaced-repetition recap: list the pattern names and ask the listener to recall the key idea aloud.
Keep the pacing deliberate so someone listening on a run can follow without pausing.
```

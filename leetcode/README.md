# LeetCode Study Area

Python is our primary language for first-pass solutions. It keeps the feedback loop tight while we focus on pattern recognition. Once we like the walkthrough, we can layer in Ruby, Go, or TypeScript excerpts as optional follow-ups.

## Daily Workflow

1. **Pick a problem** from a category directory (start with `arrays-and-strings/`).
2. **Copy `templates/problem-guide.md`** into the problem folder and rename it (e.g., `two-sum.md`).
3. **Solve in Python** inside the markdown file using a minimal class or function. Favour clarity over micro-optimisations on the first draft.
4. **Validate quickly** with `python -m pytest` if you create test files, or inline `assert` statements you can run with `python path/to/file.py`.
5. **Document the story**: what happened, why the approach works, DevOps tie-ins, and follow-up questions.

## Python Snippets

- Keep example code runnable by pasting into a file like `leetcode/scratch/two_sum.py` as needed.
- Use `typing` hints to make the explanations easier to follow when NotebookLM summarises.
- Capture edge cases in the table so we can replay them when revising.

## Suggested Commands

```bash
# run a quick ad-hoc script
python leetcode/scratch/two_sum.py

# run pytest once we start collecting tests
python -m pytest leetcode/tests
```

> Reminder: stay ASCII-only unless the problem explicitly requires unicode.

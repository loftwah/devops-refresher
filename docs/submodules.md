# Git Submodules (Practical Guide)

Use this as a quick reference for when and how to use submodules in this repo.

## What & Why

- Submodule: a Git repository embedded inside another repo at a specific path and commit.
- Why here: `demo-node-app` is a standalone, real application with its own lifecycle. We vendor it as a submodule to keep its history and CI/CD independent while referencing a known state from this repo.

## When To Use vs. Avoid

- Use when:
  - You need to include a separate, versioned project (e.g., demo app, shared library) without merging histories.
  - You want to pin to a known commit while keeping independent pipelines and releases.
- Avoid when:
  - Codebases are tightly coupled and iterate together (prefer monorepo or subtree).
  - Contributors regularly miss updating submodules (adds friction).

## Cloning and Updating

- Clone with submodules:

```
git clone --recursive https://github.com/loftwah/devops-refresher.git
```

- Or initialize after cloning:

```
cd devops-refresher
git submodule update --init --recursive
```

- Update to latest upstream on tracked branch (here we track `main`):

```
cd demo-node-app && git pull origin main && cd -
git add demo-node-app
git commit -m "chore: bump demo app submodule"
```

Tip: We set `.gitmodules` to track `branch = main`, but submodules are still pinned by commit in this repo. You have to bump the pointer by committing an updated submodule state as shown above.

## CI/CD Considerations

- This repo’s infra labs do not require submodules to deploy; they only reference container images and cluster resources.
- The demo app’s CI/CD builds from its own repository (not via submodule) — no submodule init required.
- If a workflow needs submodules (e.g., building locally from this repo):
  - GitHub Actions checkout step:

```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive
    fetch-depth: 0
```

  - Generic shell step:

```
git submodule update --init --recursive
```

- Private submodules: ensure credentials are configured (deploy keys, tokens) — not needed here because `demo-node-app` is public.

## Common Pitfalls

- “Embedded repo” warning: don’t `git add` a repo-within-repo directly. Use `git submodule add <url> <path>` so `.gitmodules` is created and clones know how to fetch it.
- Forgetting to commit the updated submodule pointer: changes in the child repo are not reflected in the parent until you `git add demo-node-app` and commit.

## Alternatives

- Git subtree: copies code into the parent with merge/squash; simpler for consumers, loses separate CI unless designed for it.
- Packages/artifacts: publish the child as a versioned package or container image and depend on it.

## This Repo’s Practice

- Path: `demo-node-app` (public GitHub repo)
- Tracking: `branch = main` in `.gitmodules`, pointer pinned by commit in this repo
- Deployments: CI/CD for the app runs from `demo-node-app`; infra labs do not require submodule initialization

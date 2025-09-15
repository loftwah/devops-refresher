### Fix: Submodule changes made on a local branch that was already merged and deleted upstream

This runbook documents how we got into a broken state by committing a submodule update while on a local branch whose remote had already been merged and deleted, the symptoms we observed, and the steps to safely clean it up.

### Symptoms

- `git pull` fails on the feature branch with:

```bash
fatal: couldn't find remote ref <branch>
```

- `git status -sb` shows the local branch tracking a deleted upstream:

```bash
## <branch>...origin/<branch> [gone]
```

- `git branch -vv` confirms multiple branches with gone upstreams:

```bash
dl/foo 1234abc [origin/dl/foo: gone] ...
```

- `git submodule status` may show the submodule at a specific commit, sometimes detached or out-of-date:

```bash
 f574324 demo-node-app (heads/main)
```

### Root cause

- A local branch (e.g. `dl/glossary`) had already been merged to `main` and the remote branch was deleted.
- We stayed on that local branch and committed a submodule pointer change. The branch now had new local commits but still “tracked” a remote ref that no longer existed.
- Any attempt to pull from the deleted upstream fails; pruning didn’t remove the local branch, leaving a confusing state with submodule updates on a branch that should no longer exist.

### Resolution

1) Prune remote refs and tags; identify default branch

```bash
git fetch --all --tags --prune --prune-tags --force
git remote show origin        # shows origin/HEAD (e.g. main)
```

2) Switch to the default branch and update

```bash
git checkout main
git pull --ff-only
```

3) If needed, recover any local work before deleting the branch

- If the branch contains unique commits you need to keep, either:
  - `git cherry-pick <commit>` onto `main`, or
  - `git merge --no-ff <branch>` from `main` (if appropriate), or
  - `git switch -c rescue/<old-branch>` to park the work temporarily.

4) Delete merged branches safely

- Delete a single merged branch:

```bash
git branch -d <branch>
```

- Bulk delete only branches that are merged into `main` and whose upstream is gone:

```bash
comm -12 \
  <(git branch -vv | awk '/\[gone\]/{print $1}' | sed 's/^..//' | sort) \
  <(git branch --merged main | sed 's/^..//' | sort) \
| xargs -r -n1 git branch -d
```

- Force delete any branches whose upstreams are gone (use when you’re sure the work is not needed):

```bash
git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
| awk '$2 ~ /\[gone\]/{print $1}' \
| xargs -r -n1 git branch -D
```

5) Sync and update submodules

```bash
git submodule sync --recursive
git submodule update --init --recursive
git submodule status --recursive
```

### Prevention

- Delete local feature branches immediately after they are merged upstream.
- Enable automatic pruning on fetch:

```bash
git config --global fetch.prune true
git config --global remote.origin.prune true
```

- Consider always doing submodule bumps from an up-to-date `main` or an active feature branch that still exists upstream.
- Optionally enable recursive submodule operations to reduce surprises:

```bash
git config --global submodule.recurse true
```

### Quick checklist

- Prune remotes and tags
- Update `main`
- Migrate or discard any local-only commits on dead branches
- Delete stale local branches (merged and/or upstream gone)
- `git submodule sync && git submodule update --init --recursive`



# Git

Okay, let's begin the Git refresher. Picture yourself at your terminal in Melbourne, coffee in hand, screen off — you're listening to this, imagining the commands as I describe them. Git is a distributed version control system, which means it's not like old tools where everything lives on a central server. Instead, your local copy has the full history, all commits, branches, tags, everything. If GitHub goes down, you can still commit, branch, and even share with teammates via bundles or direct pushes. The key concept is snapshots: each commit is a full picture of your project at that moment, but Git stores it efficiently by only saving changes from the previous snapshot. This makes it fast and powerful.

First, make sure Git is set up. You open your terminal and type git space dash dash version to check if it's installed and what version you're on. If it says something like "git version 2.46.0," you're good. If not, on Ubuntu you'd type sudo space apt space update and then sudo space apt space install space git. On macOS, brew space install space git if you have Homebrew. On Windows, you download from git-scm.com or use winget space install space dash dash id Git dot Git space dash dash source space winget. Why do this check? Because different versions have different features, like git switch in newer versions versus git checkout in older ones. Example: you're troubleshooting a problem, and your teammate has a different version; knowing yours helps debug why a command works for them but not you.

Now, configure Git globally. These settings apply to all repositories on your machine unless overridden locally. You type git space config space dash dash global space user dot name space quote Dean space Lofts quote. Then git space config space dash dash global space user dot email space quote dean at dean lofts dot x y z quote. Why? Every commit includes this info, so when you push to GitHub or run git log, it shows who did what. Without it, commits might show as "unknown author," which looks unprofessional. Example: you're contributing to an open-source project like NASA's Open MCT, as you have; with this set, your commits show "Dean Lofts" and link to your email for credit.

Next, set the default branch for new repos. Type git space config space dash dash global space init dot defaultBranch space main. This changes the default from "master" to "main" when you run git init. Why? Many teams have moved to "main" for inclusivity, and it's the default on GitHub now. Example: you create a new repo for your TechDeck project; with this setting, it starts on main, matching your team's convention.

Handle line endings to avoid cross-platform headaches. On Linux or macOS, type git space config space dash dash global space core dot autocrlf space input. This means Git converts CRLF to LF on commit and leaves LF on checkout. On Windows, use true instead, which converts LF to CRLF on checkout. Why? Windows uses CRLF line endings, Unix uses LF. Without this, pulling files from a Windows teammate could show the entire file as changed in git diff. Edge case: if you're working on a script that must preserve exact line endings, set core.autocrlf to false locally with git config core.autocrlf false. Example: in your Rails app, a teammate on Windows commits a script; without this setting, you pull and Git thinks it's all new lines, causing unnecessary conflicts. With it, Git normalizes everything to LF in the repo.

For colored output in the terminal, type git space config space dash dash global space color dot ui space auto. This makes git status, diff, and log use colors for readability — green for added, red for removed. Why? Makes scanning output faster, especially in long diffs. Example: you run git diff on a large file; colors highlight additions and removals, so you spot bugs quicker.

Set your default editor for commit messages. Type git space config space dash dash global space core dot editor space quote nano space dash w quote for Nano, or vim, or code space dash dash wait for VS Code. Why? When you run git commit without -m, or git rebase -i, it opens this editor. Example: during an interactive rebase, it opens Vim; if you prefer Nano, this setting saves you exiting and re-editing.

For pull behavior, type git space config space dash dash global space pull dot rebase space true. This makes git pull do a rebase instead of merge by default. Why? Keeps history linear, avoiding merge commits. Edge case: if you want merge commits to preserve branch history, set it to false. Example: you pull on a feature branch; with this, it rebases onto the latest main, keeping a clean line.

For push behavior, type git space config space dash dash global space push dot default space simple. This pushes only the current branch to its upstream. Why? Safer than pushing all branches. Example: you have multiple branches locally; with this, git push only sends the current one, preventing accidental pushes.

Set aliases for shortcuts. Type git space config space dash dash global space alias dot st space status. Now git st equals git status. Add alias.dot co space checkout, alias.dot br space branch, alias.dot ci space commit, alias.dot lg space log space dash dash pretty equals format colon percent C h space dash dash graph. Why? Saves typing in daily work. Example: you type git lg to see a nice graph log instead of the full command every time.

For signing commits, type git space config space dash dash global space commit dot gpgsign space true and git space config space dash dash global space user dot signingkey space your key ID. First, generate a GPG key with gpg space dash dash full dash generate dash key. Or for SSH signing, git space config space dash dash global space gpg dot format space ssh and git space config space dash dash global space user dot signingkey space tilde slash dot ssh slash id ed two five five one nine dot pub. Why? GitHub verifies signed commits, preventing tampering. Edge case: if your key has a passphrase, it prompts each commit; use gpg-agent to cache it. Example: you commit and push; GitHub shows a green "Verified" badge next to your name.

For credential helpers, to cache GitHub tokens, type git space config space dash dash global space credential dot helper space cache. Why? Avoids re-entering your personal access token every push. Example: you push to a private repo; enter token once, it's cached for 15 minutes by default.

Now, creating and cloning repositories. To create a new one, cd into a folder and type git space init. Git sets up .git with HEAD pointing to refs/heads/main (or master if not configured), an empty index, and objects directory. Why? This initializes the database for tracking. Example: for your LoftwahFM project, you mkdir loftwahfm, cd loftwahfm, git init, then add your initial files.

To add initial files, create them, then git add . to stage all, then git commit -m "Initial commit" — git space commit space dash m space quote Initial commit quote. Why the initial commit? Establishes the root of history. Example: you add README.md with "AI-powered music platform," git add README.md, commit.

To clone, git space clone space git at github dot com colon yourorg slash repo dot git. For HTTPS, replace with https://github.com/yourorg/repo.git. Add --origin myorigin to name the remote. Why clone? Gets a full working copy. Edge case: for large repos, add --filter=blob:none for partial clone, fetching blobs lazily. Example: cloning Linux for pirates repo, git clone https://github.com/yourname/linuxforpirates.git, cd into it, git branch to see branches.

The staging area is key. It's the index file in .git, holding what will be committed. To see what's staged, git status shows "changes to be committed." To diff staged, git diff --staged. Why staging? Allows partial commits. Example: you change five lines in app.rb; git add -p lets you stage three, commit "fix bug," stage remaining two, commit "add logging."

To ignore files, edit .gitignore with patterns: \*.log ignores logs, /build ignores build dir, !important.log to exception. Why? Keeps repo clean. Example: in Rails, add .env to .gitignore so secrets don't commit.

Remotes are pointers to other repos. After clone, origin is set. To add, git remote add upstream git@github.com:original/repo.git. To rename, git remote rename old new. To remove, git remote remove upstream. Why multiple remotes? Sync with fork and original. Example: you fork a repo, clone your fork, add upstream to original, fetch upstream, merge upstream/main.

Fetching: git fetch origin updates local tracking branches like origin/main. Why fetch? See changes without applying. Example: git fetch, git log origin/main to see new commits.

Pulling: git pull origin main — fetches and merges. With rebase config, it rebases. Example: on main, git pull pulls latest, merges or rebases.

Pushing: git push origin main. If rejected, pull first. For force, git push --force-with-lease — safer than --force. Why lease? Checks if remote changed. Example: after rebase, push --force-with-lease.

Branching: git branch lists. git branch -r remote ones. git branch -a all. To create from commit, git branch new-branch SHA. To move, git branch -f main HEAD~3. Example: git branch hotfix, git checkout hotfix, fix, push.

Merging: git merge hotfix on main. --no-ff forces merge commit. --ff-only only if fast-forward. Why no-ff? Preserves branch history. Example: git merge --no-ff feature, creates merge commit.

Rebase: git rebase main on feature. --interactive or -i for editing: git rebase -i HEAD~5, pick, reword, squash commits. Why squash? Combines for clean history. Example: rebase -i, mark squash on fixup commits, save, new history.

Stash: git stash save "wip" (old) or git stash push -m "wip". -u includes untracked. Apply: git stash apply. Pop: git stash pop. Drop: git stash drop. Branch from stash: git stash branch new-branch. Why? Quick switch without committing. Example: mid-change, stash, fix bug on main, pop back.

Cherry-pick: git cherry-pick SHA. -e to edit message. -n no commit. For range, git cherry-pick start..end. Why? Selective backports. Example: on main, cherry-pick bugfix SHA from develop, resolve conflicts, continue.

Reset: git reset --soft SHA keeps staged. --mixed unstages. --hard discards. Why? Undo local commits. Example: reset --hard HEAD~1 drops last commit.

Revert: git revert SHA creates undo commit. Why? Safe for pushed commits. Example: revert bad push, push revert.

Reflog: git reflog show --all. Recover: git reset --hard reflog-entry. Why? Safety net. Example: after bad reset, reflog, find SHA, reset to it.

Bisect: git bisect start, bisect bad, bisect good SHA, test, bisect good/bad, reset. --term-old/--term-new for custom labels. Why? Binary search bugs. Example: test fails, bisect to find introducing commit.

Tags: git tag v1.0, or -a v1.0 -m "release". Push: git push origin v1.0. Delete: git tag -d v1.0, git push --delete origin v1.0. Why? Mark releases. Example: tag release, push tags.

Hooks: edit .git/hooks/pre-commit, make executable, add script like #! /bin/sh, ruby -c \*_/_.rb. Why? Automate checks. Example: pre-commit lints code, blocks bad commits.

Submodules: git submodule add https://github.com/lib/repo lib. Update: git submodule update --init --recursive. Why? Nested repos. Example: add Redis lib as submodule, commit.

Worktrees: git worktree add ../review main. Why? Multiple branches checked out. Example: worktree for PR review while on feature.

Sparse checkout: git sparse-checkout init --cone, git sparse-checkout set dir1 dir2. Why? Partial repo. Example: monorepo, checkout only backend dir.

Internals: git show-ref for refs. git ls-tree SHA for tree. git cat-file -p SHA for content. Why? Debugging. Example: cat-file on blob shows file content.

Plumbing: git hash-object -w file for SHA. git update-index --add file for staging. Why? Low-level scripting. Example: script to add files.

Collaboration: In trunk-based, commit small to main. Git Flow: release branches. Example: feature branch, PR with description, review, squash merge.

Secrets: If leaked, git filter-repo --invert-paths --path .env, force push. Why? Remove from history. Example: rotate key, clean history.

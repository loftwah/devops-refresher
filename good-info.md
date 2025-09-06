# This is info I find I need to Google

- [amp manual for Cursor sidebar](https://ampcode.com/manual)

## Customize Layout in Cursor

Third party extensions are automatically placed in the primary sidebar in Cursor. To customize the position of Amp in Cursor please follow these steps:

- Open the Command Pallete using Ctrl/⌘ + Shift + P
- Search for View: Move View
- Select Amp from the drop down list
- Choose your desired location (New Panel Entry and New Secondary Side Bar Entry are the most common)

# Home drive backup to Pi

- Host: `loftwah@192.168.1.103`. Destination: `/mnt/data/home/loftwah/`.

```
# 1) SSH in and create the destination (one-time, needs sudo):
ssh -t loftwah@192.168.1.103 'sudo mkdir -p /mnt/data/home/loftwah && sudo chown -R $USER:$USER /mnt/data/home/loftwah'

# 2) Simple rsync (repeatable): local home -> Pi
rsync -avz --delete -e ssh "$HOME"/ loftwah@192.168.1.103:/mnt/data/home/loftwah/

# 3) Simple remote tar (on the Pi):
ssh loftwah@192.168.1.103 "tar -czvf /mnt/data/home/loftwah/mbp-m4-home-drive-backup-$(date +%Y-%m-%d).tar.gz -C / home/loftwah/"
```

## Prettier via npx

Format code on demand without adding a local dependency.

- src only:

```
npx prettier --write src
```

- Whole repo, excluding `.venv/` via `.prettierignore`:

```
# One-time: ensure Prettier ignores your virtualenv
printf ".venv/\n" >> .prettierignore

# Then format everything supported in the repo
npx prettier --write .
```

- Reuse `.gitignore` (optional):

```
npx prettier --ignore-path .gitignore --write .
```

Notes:
- You do not need to list extensions; Prettier detects and formats only supported file types.
- Use globs only when you want to target a subset of files (e.g., `"src/**/*.ts"`). Quote globs to avoid shell expansion.
- Add other folders to `.prettierignore` to exclude them (e.g., `dist/`, `coverage/`).

# Publishing

## Goal

Publish this repository for the first time to:

```text
git@github.com:qmatiaslopez/droidex-sandbox.git
```

## Pre-push checklist

- `codex-lb/.env` does not exist in the staged tree
- `sandboxes/projects/` contains no generated projects
- no personal paths remain in scripts or docs
- no local tokens, keys, or generated settings are tracked
- `README.md` and `docs/` reflect the current runtime behavior

## Initialize Git

If the directory is not already a Git repository:

```bash
git init
git branch -M main
git remote add origin git@github.com:qmatiaslopez/droidex-sandbox.git
```

If `origin` already exists, update it instead:

```bash
git remote set-url origin git@github.com:qmatiaslopez/droidex-sandbox.git
```

## First push flow

```bash
git add .
git status
git commit -m "Initial repository import"
git push -u origin main
```

Review `git status` before committing. Do not include local runtime files.

## Files that must never be pushed

- `codex-lb/.env`
- `sandboxes/projects/**/.env.local`
- `sandboxes/projects/**/.factory-container-settings.json`
- cloned repos under `sandboxes/projects/**/repo/`
- local caches and runtime artifacts

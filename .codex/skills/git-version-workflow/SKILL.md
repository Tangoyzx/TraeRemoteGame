---
name: git-version-workflow
description: Safe Git version workflows for this workspace. Use when the user asks to discard/reset local changes and update the current branch to the remote latest, or to commit local workspace changes and push them to the current branch's remote. Prefer the bundled PowerShell scripts over hand-written git command sequences for reset, update, commit, publish, push, and remote synchronization tasks.
---

# Git Version Workflow

Use the bundled PowerShell scripts for repeatable Git workflows in this workspace.

## Reset current branch to remote latest

Use this when the user asks to discard local changes, recover a clean workspace, update to the latest remote version, or reset to `origin/<current-branch>`.

1. Warn that this is destructive: tracked changes and untracked files will be removed.
2. Request approval for the destructive action and for network access if needed.
3. Preview first when helpful:

```powershell
.\.codex\skills\git-version-workflow\scripts\reset-to-remote-latest.ps1
```

4. Execute after approval:

```powershell
.\.codex\skills\git-version-workflow\scripts\reset-to-remote-latest.ps1 -Force
```

Add `-IncludeIgnored` only if the user explicitly wants ignored files such as build outputs removed too.

## Publish local changes to remote

Use this when the user asks to submit, commit, publish, or push local changes.

1. Inspect the working tree first if context is needed.
2. **Bump the game version**: open `scripts/main.gd`, find `const GAME_VERSION := "vX.Y.Z"`, and increment the **last segment (patch)** by 1 (e.g. `v1.0.3` → `v1.0.4`). This version is shown at the top-center of the game screen and must advance on every publish. Do not skip this step even if the changes are non-functional.
3. Use a concise commit message based on the actual changes.
4. Run:

```powershell
.\.codex\skills\git-version-workflow\scripts\publish-local-to-remote.ps1 -Message "Your commit message"
```

The script stages all changes, commits them if needed, and pushes the current branch to `origin/<current-branch>`. Use `-NoPush` only for local dry-run style testing.

## Version bump rule (mandatory)

- **Source of truth**: `const GAME_VERSION` in [scripts/main.gd](../../scripts/main.gd). It is rendered at the top-center of the screen via `version_label`.
- **When**: Every commit that will be pushed to the remote must bump the patch segment by 1. Pure local experiments that are never pushed do not bump.
- **Format**: `vMAJOR.MINOR.PATCH`. Only `PATCH` is incremented by this rule. Bumping `MINOR`/`MAJOR` requires explicit user instruction.
- **Ordering**: Bump the version *before* staging/committing, so the version change is included in the same commit as the feature/fix it accompanies.
- **Never skip**: Even if a change feels trivial (tweaks, docs, balance), bump the patch. The visible version number is how the user verifies a new build deployed to GitHub Pages.
- **Never reuse**: The same `GAME_VERSION` string must not appear in two pushed commits. If the bump was forgotten, fix it in the next push and note the gap in the commit message.

## Branch targeting rule (mandatory)

- **Remote target**: Only push to `origin/main`. Do not create or push other remote branches.
- **Local workflow**: Local feature branches are fine for development. Before pushing, switch to local `main`, merge the feature branch into it (`--ff-only` when possible), then push `main` to `origin/main`.
- **Cleanup**: Any remote non-`main` branches created by mistake must be deleted (`git push origin --delete <branch>`) as part of the publish flow.

## Notes

- Do not use these scripts outside a Git worktree.
- Do not run the reset script with `-Force` unless the user has asked for or approved discarding local changes.
- If a script fails because of sandbox, network, or credential restrictions, rerun it with the required tool approval rather than rewriting the workflow manually.

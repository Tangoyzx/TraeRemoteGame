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
2. Use a concise commit message based on the actual changes.
3. Run:

```powershell
.\.codex\skills\git-version-workflow\scripts\publish-local-to-remote.ps1 -Message "Your commit message"
```

The script stages all changes, commits them if needed, and pushes the current branch to `origin/<current-branch>`. Use `-NoPush` only for local dry-run style testing.

## Notes

- Do not use these scripts outside a Git worktree.
- Do not run the reset script with `-Force` unless the user has asked for or approved discarding local changes.
- If a script fails because of sandbox, network, or credential restrictions, rerun it with the required tool approval rather than rewriting the workflow manually.

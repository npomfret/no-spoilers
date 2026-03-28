---
description: Update the current branch from one upstream ref with a linear history. Supports `--fast` for the clean path and `--strict` for fuller validation. Manual command only.
argument-hint: "[optional mode + upstream ref, e.g. --fast origin/main | --strict origin/main | origin/main]"
allowed-tools:
  - Read
  - Edit
  - MultiEdit
  - Write
  - Bash(git *)
  - Bash(swift *)
  - Bash(xcodebuild *)
  - Bash(xcrun *)
  - Bash(npm *)
disable-model-invocation: true
---

# Merge

Bring the current branch up to date from a single upstream ref without creating merge commits.

## Mission

- Prefer fast-forward when possible.
- Otherwise use rebase and keep history linear.
- If conflicts arise, resolve them intent-first using the inbound diff as the source of truth.

## Modes

- Default is `--strict` when no mode is provided.
- `--fast`: prioritize the clean path and skip non-essential checks when nothing conflicts.
- `--strict`: run fuller preflight and validation.

## Operating rules

- If upstream is ambiguous and cannot be inferred safely, ask the user exactly once.
- Never use `git pull`.
- Never use interactive Git flows.
- If the working tree has local changes, auto-stash before rebase and restore afterward.
- Prefer per-command Git config over persistent repo config writes.
- Treat actual code diffs as authoritative when commit messages and code disagree.

## Required flow

1. Detect the mode from `$ARGUMENTS`.
2. Detect the upstream from `$ARGUMENTS`, the tracking branch, `origin/HEAD`, `origin/main`, or `origin/master`, in that order.
3. Ensure the branch is not detached.
4. Fetch only the needed upstream ref.
5. Show a concise inbound commit preview before changing branch state.
6. If fast-forward is possible, use `git merge --ff-only`.
7. Otherwise rebase with `rerere` and `merge.conflictStyle=zdiff3` when available, falling back to `diff3`.
8. On conflicts:
   - inspect the base, ours, theirs, and inbound history for each file
   - write a short intent brief before editing
   - adopt upstream contracts first, then reapply still-valid local intent
   - keep edits minimal and continue the rebase cleanly
9. In `--strict` mode, run the smallest meaningful verification for affected areas after the update.
10. Report mode, strategy, inbound commit count, conflicted files if any, validation run, and residual risks.

## Verification guidance

- Route compile or build confidence through `build-verify`.
- Prefer canonical repo commands or wrappers over ad-hoc checks.
- When the repo has not standardized wrappers yet, use the smallest meaningful direct command for the affected scope and report it exactly.

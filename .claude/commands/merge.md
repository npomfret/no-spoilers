---
description: Update the current branch from an upstream reference while preserving linear history and other agents' work.
argument-hint: "[--fast | --strict] [upstream]"
disable-model-invocation: true
---

# Update from upstream

Use the shared Git policy in AGENTS.md. Infer the upstream from the tracking branch or remote default when none is supplied; ask if it remains ambiguous.

- Inspect status and incoming changes before updating. Preserve unrelated work; use an isolated worktree rather than stashing it.
- Fetch the upstream, fast-forward when possible, otherwise rebase. Resolve conflicts from both sides' intended behavior and verify the affected result. Do not create merge commits.
- Keep per-command Git settings local to the operation. Stage only the conflict resolutions that belong to this work.
- Default to --strict: run relevant verification for the resulting change. --fast may skip extra checks on a conflict-free update. Use project entry points rather than inventing build commands.
- Do not force-push the default branch. A previously pushed branch of your own may use --force-with-lease after rebase.

Report the upstream, resulting revision, update strategy, resolved conflicts and verification. Do not push unless that delivery is authorized.

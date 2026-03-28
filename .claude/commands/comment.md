---
description: Draft a commit message for the current changeset. Manual command only.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git *)
disable-model-invocation: true
---

# Comment

Draft a commit message for the current changeset.

- Analyze staged and unstaged changes first.
- If untracked files are present, call that out before drafting the message.
- Do not stage, unstage, commit, push, or edit files.
- Output:
  - one concise subject line
  - blank line
  - one short paragraph per concern when the changeset mixes concerns
- Keep the message intent-focused, not file-by-file.
- After the message, offer an optional split suggestion if the changeset mixes concerns.

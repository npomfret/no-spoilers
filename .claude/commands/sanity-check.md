---
description: Run a read-only working-tree sanity check for correctness risks, duplication, and missing verification. Manual command only.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
disable-model-invocation: true
---

# Sanity Check

Run a read-only review of the current working tree.

- Do not edit, stage, unstage, commit, or delete files.
- Read `.claude/rules/core.md` and the path rules that match the touched files, and identify the approved local pattern for each touched concern.
- Treat duplicated implementations and pattern drift as correctness findings, not style.
- Use `pattern-compliance-reviewer` when the change surface is broad or architectural.
- Focus on correctness risks, regressions, duplicated implementations, missing verification, and platform drift.
- Output:
  - brief status summary
  - findings ordered by severity
  - build or test confidence by evidence
  - open risks or questions

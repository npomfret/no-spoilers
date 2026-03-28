---
description: Run a read-only working-tree sanity check for correctness risks, duplication, and missing verification. Manual command only.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git *)
disable-model-invocation: true
---

# Sanity Check

Run a read-only review of the current working tree.

- Do not edit, stage, unstage, commit, or delete files.
- Use `review-working-tree` as the primary workflow.
- Keep `pattern-governance-reference` active for the whole review.
- Use `pattern-compliance-reviewer` when the change surface is broad or architectural.
- Focus on correctness risks, regressions, duplicated implementations, missing verification, and platform drift.
- Output:
  - brief status summary
  - findings ordered by severity
  - build or test confidence by evidence
  - open risks or questions

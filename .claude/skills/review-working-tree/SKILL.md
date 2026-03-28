---
name: review-working-tree
description: Review current changes for correctness risks, regressions, missing verification, pattern drift, and unnecessary duplication. Use for read-only audits or code review. Do NOT use when the task expects code edits.
user-invocable: true
---

# Review Working Tree

## Goal

Review the current working tree without editing files and surface the highest-value findings first.

## Required flow

1. Inspect the working tree and changed scope.
2. Read `.claude/rules/core.md` and any path-specific rules that match the touched files.
3. Load `pattern-governance-reference` and identify the approved local pattern for each touched concern.
4. Use `pattern-compliance-reviewer` when a focused read-only pass for duplication or drift would help.
5. Identify correctness risks, regressions, missing verification, duplication, architecture drift, and silent platform divergence.
6. Keep findings concrete, file-specific, and ordered by severity.
7. Call out missing command evidence or missing test coverage when confidence is being overstated.

## Do not

- Do not edit files in this skill.
- Do not bury important risks under low-value style comments.
- Do not treat duplicated implementations or inconsistent patterns as minor style issues.

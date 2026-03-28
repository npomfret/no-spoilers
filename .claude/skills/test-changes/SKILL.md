---
name: test-changes
description: Run the smallest valid behavior-risk or regression verification using the repo's approved test flow. Use after bug fixes, changed behavior, regressions, or when the user asks what tests should cover a change. Do NOT use when only compile or build confidence is needed; use `build-verify` for that.
user-invocable: true
---

# Test Changes

## Goal

Run and report the smallest valid verification for changed behavior with deterministic evidence.

## Required flow

1. Read `.claude/rules/testing.md`.
2. Read `.claude/rules/apple-platforms.md` if the change touches Swift, Apple-platform UI, or project configuration.
3. Confirm the real test entry points from the repo before running commands.
4. If the change is substantial or architectural, keep `pattern-governance-reference` active so verification is matched to the approved pattern.
5. Choose the smallest meaningful test scope for the changed behavior.
6. Prefer repo-approved wrappers or scripts. If the right shared wrapper is missing, note that gap instead of normalizing ad-hoc broad test runs.
7. If a test fails and code changes are needed, state one concrete root-cause hypothesis and the smallest safe fix scope before editing.
8. Report exact commands, pass or fail per command, and remaining coverage gaps.

## Do not

- Do not default to the full suite unless the changed behavior truly requires it.
- Do not claim tests passed without executed command evidence.
- Do not bypass an approved repo verification flow.

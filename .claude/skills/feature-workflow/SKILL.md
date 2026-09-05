---
name: feature-workflow
description: Use automatically for non-trivial features, behavior changes, and refactors. Audits the full path, prepares the design, implements, and verifies without pattern drift. For observed failures, also use bug-investigation. Do not use for documentation-only or mechanical edits.
user-invocable: true
---

# Feature Workflow

## Goal

Deliver non-trivial product or code changes without introducing pattern drift, duplicated behavior, or local patches that make the surrounding system worse.

## Required flow

1. Load applicable path rules and `pattern-governance-reference` before writing.
2. Use `task-files` to create or update the task file required for planned or complex work.
3. Define the observable outcome and the checks that will prove it.
4. Inspect the current implementation before planning edits:
   - upstream callers and entry points
   - downstream implementations and consumers
   - lateral files that solve the same concern
   - nearest tests or task files
5. Identify the approved local pattern for the touched concern.
6. Assume the area may not be ready for the requested change. If readiness refactoring is needed, do that first and keep it tied to the requested outcome.
7. If no approved pattern exists, stop and propose the new standard before implementing it broadly.
8. If the task is Apple-platform implementation work, use `implement-apple-change`.
9. If the task changes behavior, use `test-changes` to add or update coverage and run the smallest meaningful verification before handoff.
10. If the task needs compile or toolchain confidence, plan the smallest meaningful `build-verify` check before handoff.
11. Delegate broad discovery to `codebase-explorer`; use `pattern-compliance-reviewer` for a second read-only pass when the change is architectural or cross-cutting.
12. Record the approved pattern in the task file alongside the plan and verification.

## Stop and ask before

- introducing a new dependency
- introducing a new architectural pattern, service layer, helper family, file layout, or naming convention
- preserving accidental compatibility that conflicts with a cleaner current design
- deleting or rewriting broad areas where user intent is ambiguous
- using external systems when code, tests, configuration, and local evidence can answer the question

## Do not

- Do not patch the nearest file before checking for the established pattern.
- Do not keep duplicate old and new implementations unless the task explicitly requires a temporary migration.
- Do not add hidden fallbacks, default values, or sentinel behavior for data that should be present.
- Do not claim completion without exact command evidence.

---
name: feature-workflow
description: Use PROACTIVELY for non-trivial features, bug fixes, behavior changes, or refactors so work starts with discovery, readiness refactoring, approved-pattern selection, and verification planning before implementation.
user-invocable: true
---

# Feature Workflow

## Goal

Deliver non-trivial product or code changes without introducing pattern drift, duplicated behavior, or local patches that make the surrounding system worse.

## Required flow

1. Read `.claude/rules/core.md` and any path-specific rules for the touched files.
2. Read `docs/guides/general.md`, `docs/guides/workflows-and-tasks.md`, and `docs/guides/important-code.md`.
3. Load `pattern-governance-reference`.
4. Inspect the current implementation before planning edits:
   - upstream callers and entry points
   - downstream implementations and consumers
   - lateral files that solve the same concern
   - nearest tests or task files
5. Identify the approved local pattern for the touched concern.
6. Assume the area may not be ready for the requested change. If readiness refactoring is needed, do that first and keep it tied to the requested outcome.
7. If no approved pattern exists, stop and propose the new standard before implementing it broadly.
8. If the task is Apple-platform implementation work, use `implement-apple-change`.
9. If the task changes behavior, plan the smallest meaningful `test-changes` verification before handoff.
10. If the task needs compile or toolchain confidence, plan the smallest meaningful `build-verify` check before handoff.
11. For broad or architectural changes, use `codebase-explorer` for discovery and `pattern-compliance-reviewer` for read-only drift review.

## Stop and ask before

- introducing a new dependency
- introducing a new architectural pattern, service layer, helper family, file layout, or naming convention
- preserving accidental compatibility that conflicts with a cleaner current design
- deleting or rewriting broad areas where user intent is ambiguous
- using browser, MCP, or external tools before repo inspection has been exhausted

## Do not

- Do not patch the nearest file before checking for the established pattern.
- Do not keep duplicate old and new implementations unless the task explicitly requires a temporary migration.
- Do not add hidden fallbacks, default values, or sentinel behavior for data that should be present.
- Do not claim completion without exact command evidence.

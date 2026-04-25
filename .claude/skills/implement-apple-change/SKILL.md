---
name: implement-apple-change
description: Implement or refactor Swift, SwiftUI, UIKit, AppKit, state, persistence, navigation, or Apple-platform project structure while following the repo's established patterns. Use for Apple-platform implementation work and for heavy refactors that should converge duplicated code onto one pattern. Do NOT use for read-only audits.
user-invocable: true
---

# Implement Apple Change

## Goal

Implement or refactor Apple-platform code while preserving architecture and converging duplicated or inconsistent code onto approved shared patterns.

## Required flow

1. Read the relevant files plus `.claude/rules/apple-platforms.md`.
2. Read `docs/guides/swift-patterns.md` when the task is substantial.
3. Use `feature-workflow` for non-trivial implementation, behavior change, or refactor work.
4. Load `pattern-governance-reference` and identify the nearest approved local pattern before editing.
5. If the concern already exists in multiple places, prefer convergence: refactor toward one shared boundary.
6. Reuse shared types, helpers, state boundaries, navigation patterns, and persistence access before creating new ones.
7. If the approved pattern is insufficient, refactor that shared pattern instead of introducing a variant.
8. If the code path is broad or unclear, delegate discovery to `codebase-explorer`.
9. For large or architectural changes, use `pattern-compliance-reviewer` as a read-only secondary check before sign-off.
10. Before handoff, use `build-verify` and `test-changes` as appropriate.

## Do not

- Do not introduce a second pattern for an existing concern.
- Do not add one-off helpers, managers, services, or coordinators when an approved boundary already exists.
- Do not leave duplicated behavior in place when the task naturally allows consolidation.
- Do not finish substantial refactor or implementation work without verification evidence.

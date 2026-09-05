---
name: test-changes
description: Use automatically when creating, changing, reviewing, or running tests for a feature, fix, refactor, or regression. Enforces readable behavioral tests and the smallest approved verification. Do not use when only compile confidence is needed; use build-verify.
user-invocable: true
---

# Test Changes

## Goal

Run and report the smallest valid verification for changed behavior with deterministic evidence.

## Required flow

1. Read `.claude/rules/testing.md`.
2. Read `.claude/rules/apple-platforms.md` if the change touches Swift, Apple-platform UI, or project configuration.
3. Identify the behavior, boundary, and cheapest test layer that can prove the requirement.
4. Inspect nearby tests, fixtures, builders, and assertion patterns before writing a new shape.
5. Keep each test's meaningful starting state, action, and expectation visible. Extract repeated or
   procedural setup only when it obscures the behavior; do not create opaque generic test helpers.
6. Keep expected values independent of the production logic under test, and give every test an
   isolated starting state.
7. For a testable behavior change, write or update the smallest failing test first, then implement
   the minimum change and refactor after green. Do not claim test-first work when no failing test was
   observed.
8. Treat the suite as maintained code. Consolidate or remove redundant coverage when its enduring
   risk reduction does not justify its cost.
9. Confirm the real test entry points from the repo before running commands.
10. Choose the smallest meaningful test scope for the changed behavior.
11. Prefer repo-approved wrappers. Use `scripts/verify-core-tests.sh` for shared package behavior and
    `scripts/verify-python-selftests.sh` for the Python tooling.
12. Pair focused build evidence with explicit manual or code-review evidence when app or widget
    behavior has no automated test surface.
13. If the right shared wrapper is missing, report the gap instead of normalizing an ad-hoc command.
14. Report exact commands, pass or fail per command, and remaining coverage gaps.

## Do not

- Do not default to the full suite unless the changed behavior truly requires it.
- Do not retain a bug reproducer automatically; decide whether it protects an enduring contract or
  should be rewritten, consolidated, or removed.
- Do not claim tests passed without executed command evidence.
- Do not bypass an approved repo verification flow.

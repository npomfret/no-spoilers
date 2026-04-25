# Testing Guide

Canonical testing and verification policy for this repo.

## Rules

- Never claim tests passed unless they were executed to completion.
- Run the smallest meaningful verification for the changed behavior first.
- Distinguish compile/build confidence from behavior-risk confidence.
- After a bug fix or behavior change, rerun the relevant verification before handoff.
- Prefer deterministic tests and explicit evidence over broad “should be fine” claims.
- If the repo standardizes wrappers for tests, use them instead of ad-hoc raw commands.

## Current state

- Use `scripts/verify-core-tests.sh` for shared package behavior tests. It runs `swift test` against `NoSpoilersCore` with repo-local HOME/Foundation home, scratch, and module-cache paths, and disables SwiftPM's nested sandbox for compatibility with Claude's execution sandbox.
- For app, widget, or macOS behavior changes without dedicated UI tests, pair the smallest relevant build wrapper from `docs/guides/building.md` with focused manual or code-review evidence.
- If a new test surface is added, create or update a repo-owned wrapper before treating the command as canonical.

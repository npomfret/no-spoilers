---
name: build-verify
description: Verify compile, build, type, or toolchain health using the repo's approved verification flow. Use when the user asks for build confidence, compile errors, type errors, scheme issues, or toolchain failures. Do NOT use for behavior-risk testing after a fix; use `test-changes` for that.
user-invocable: true
---

# Build Verify

## Goal

Verify compile and build health for the changed scope with exact evidence reporting.

## Required flow

1. Read `.claude/rules/testing.md`.
2. Read `.claude/rules/apple-platforms.md` if the task touches Swift, Xcode, packages, plist, or entitlements.
3. Confirm the real verification entry points from the repo itself before running commands.
4. If the change is substantial or architectural, keep `pattern-governance-reference` active so verification is matched to the approved pattern.
5. Choose the smallest meaningful build, compile, type, or lint scope for the affected area.
6. Prefer the repo's shared wrappers or scripts:
   - `scripts/verify-mac-build.sh` for the macOS app
   - `scripts/verify-ios-build.sh` for the iOS app
   - `scripts/verify-widget-build.sh` for the widget extension
   - `scripts/verify-core-tests.sh` when package test compilation is the smallest useful compile check
7. If a wrapper does not fit the touched scope, use the smallest direct tool invocation supported by the repo and note whether a wrapper should be added or updated.
8. If a check fails and code changes are needed, state the smallest safe fix scope before editing.
9. Report exact commands, pass or fail status, and remaining gaps.

## Do not

- Do not default to broad test execution when compile or build confidence is enough.
- Do not invent schemes, targets, package products, or flags.
- Do not claim success with unresolved build or toolchain failures.

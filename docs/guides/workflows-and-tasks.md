# Workflows And Tasks Guide

Canonical workflow routing and task-tracking policy for this repo.

## Preferred workflows

These are the main repo workflows. Claude should infer them from intent instead of waiting for a slash command.

- `pattern-governance-reference` for substantial work, refactors, reviews, or any task where multiple implementations are possible
- `feature-workflow` for non-trivial features, bug fixes, behavior changes, and refactors
- `implement-apple-change` for Swift, SwiftUI, UIKit, AppKit, state, persistence, navigation, or project-structure work
- `build-verify` for compile, build, type, and toolchain verification
- `test-changes` for targeted behavior-risk verification
- `review-working-tree` for read-only review of correctness, duplication, pattern drift, and missing verification
- `claude-setup-maintenance` for changes to Claude instructions, rules, skills, agents, hooks, commands, and verification wrappers

## Manual convenience commands

These are explicit user affordances, not the primary routing surface:

- `/comment` for commit-message drafting
- `/merge` for the controlled linear-history update workflow
- `/sanity-check` for a read-only working-tree review

Do not auto-run manual-only commands unless requested.

## Automatic intent routing

- If the request is broad, architectural, or likely to introduce inconsistent code, load `pattern-governance-reference` first.
- If the request is a non-trivial feature, bug fix, behavior change, or refactor, use `feature-workflow`.
- If the request is to implement or refactor Apple-platform code, use `implement-apple-change`.
- If the request is to verify compile/build/toolchain confidence, use `build-verify`.
- If the request is to verify changed behavior or regression risk, use `test-changes`.
- If the user asks for review, audit, sanity checking, or compliance, use `review-working-tree`.
- If the request changes Claude Code setup or repo workflow policy, use `claude-setup-maintenance`.

## Feature workflow

For non-trivial implementation work, Claude must:

1. inspect upstream, downstream, lateral implementations, and nearest tests before editing
2. identify the approved local pattern for the touched concern
3. refactor for readiness when the current shape cannot cleanly host the requested change
4. implement against the approved pattern
5. verify with the smallest meaningful build or behavior-risk check
6. report exact command evidence

## Pattern-first rule

- Before editing, identify the approved local pattern for the touched concern.
- If a shared abstraction almost fits, improve it instead of creating a variant.
- If the same concern already exists in multiple places, convergence is preferred: refactor toward one implementation.
- Pattern drift, duplicate helpers, and alternate implementations are correctness findings.

## Agent delegation

- Use `codebase-explorer` for broad discovery, tracing, and identifying the approved local pattern before implementation.
- Use `pattern-compliance-reviewer` for read-only checks focused on duplicate implementations, pattern drift, and boundary violations.
- Parallelize only when file ownership is cleanly disjoint.

## Tasks

Track substantial multi-step work in `tasks/*.md`.

- Create a task file when work is more than a minor one-off change.
- Capture the goal, constraints, approved pattern, plan, verification, and open risks.
- Update the task file as implementation progresses.
- Keep it concise and current.

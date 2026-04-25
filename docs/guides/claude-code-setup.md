# Claude Code Setup Guide

Canonical guide for maintaining this repo's Claude Code control plane.

## Layer model

- `CLAUDE.md` is the short root operating contract: non-negotiables, routing, and pointers to deeper guidance.
- `.claude/rules/` contains always-on and path-scoped rules.
- `.claude/skills/` contains repeatable workflows and subsystem conventions that Claude should route to from user intent.
- `.claude/agents/` contains reusable specialists, especially read-only discovery and drift review.
- `.claude/commands/` contains manual slash-command affordances.
- `.claude/hooks/` contains fast deterministic reminders and side effects.
- `docs/guides/` contains longer reference material that should not live in always-on memory.
- `scripts/` contains canonical command wrappers for repeated verification.

## Maintenance rules

- Keep root memory concise. Do not add long conventions, troubleshooting playbooks, or subsystem manuals to `CLAUDE.md`.
- Add or update a skill when a workflow should be repeatable and discoverable from user intent.
- Add or update a rule when an instruction is always-on or path-scoped.
- Add or update a guide when the content is explanatory reference material.
- Add or update a wrapper script when a command becomes canonical or needs environment setup.
- Update `docs/guides/important-code.md` when the control plane changes.

## Feature-work posture

- Audit before implementing.
- Identify the approved local pattern before editing.
- Refactor for readiness when the current shape cannot cleanly host the requested change.
- Implement against the approved pattern.
- Verify with the smallest meaningful command.
- Treat duplicate helpers, variant architectures, and silent pattern drift as correctness issues.

## Tool and ecosystem policy

- Prefer code, tests, project files, and docs before external tools.
- Use gstack `/browse` for web browsing when browsing is required.
- External Claude Code plugins or specialist skills are optional user-level overlays unless explicitly adopted as project policy.
- Use multiple sibling clones for genuinely independent parallel sessions; do not make worktrees the default interactive model.

## Permissions and hooks

- Keep checked-in `.claude/settings.json` safe for shared use.
- Keep personal speed settings in `.claude/settings.local.json` or user-level Claude config.
- Do not check bypass-permissions settings into shared project config.
- Use hooks for fast deterministic reminders, formatting, summaries, or audit support.
- Do not use hooks as the main access-control system.

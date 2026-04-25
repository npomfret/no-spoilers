---
name: claude-setup-maintenance
description: Use when changing CLAUDE.md, .claude rules, skills, agents, hooks, commands, settings, or Claude-facing guides so the control plane stays concise, routed, and maintainable.
user-invocable: true
---

# Claude Setup Maintenance

## Goal

Keep the Claude Code setup useful for long-running work: concise root memory, explicit routing, project-owned conventions, deterministic hooks, and concrete verification commands.

## Required flow

1. Read `CLAUDE.md`, `.claude/rules/core.md`, `docs/guides/workflows-and-tasks.md`, and `docs/guides/important-code.md`.
2. Identify the correct control-plane surface before editing:
   - `CLAUDE.md` for short always-on routing and non-negotiables
   - `.claude/rules/` for always-on or path-scoped rules
   - `.claude/skills/` for repeatable workflows and subsystem conventions
   - `.claude/agents/` for reusable read-only or delegated specialists
   - `.claude/commands/` for manual slash-command affordances
   - `.claude/hooks/` for fast deterministic side effects or reminders
   - `docs/guides/` for longer reference material
3. Keep root memory small. Move detailed guidance into skills, rules, or guides.
4. Prefer repo-owned wrappers for repeated commands instead of documenting ad-hoc raw invocations.
5. Keep checked-in `.claude/settings.json` safe for shared use. Put personal speed or permission preferences in local-only guidance.
6. Verify changed scripts or hooks with the smallest meaningful command.
7. Update `docs/guides/important-code.md` whenever the control plane changes.

## Design rules

- Skills should be discoverable from user intent and have concrete required flows.
- Rules should say what is required or forbidden, not merely "prefer consistency."
- Hooks should be fast, deterministic, and visible. Do not use hooks as the primary access-control system.
- Commands should be manual affordances; automatic routing belongs in skills and rules.
- External plugins or specialist skills are optional overlays unless explicitly adopted as project policy.

## Do not

- Do not turn scattered markdown into a parallel rules system.
- Do not add broad blocking hooks for normal development actions.
- Do not vendor external Claude plugins into the repo without explicit approval.
- Do not add bypass-permissions settings to shared project config.

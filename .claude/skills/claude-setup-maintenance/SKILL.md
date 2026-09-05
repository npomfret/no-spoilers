---
name: claude-setup-maintenance
description: Use automatically when creating, changing, reviewing, or diagnosing CLAUDE.md, .claude configuration, project skills, agents, hooks, commands, settings, or Claude-facing references. Keeps policy single-owned and native discovery reliable.
user-invocable: true
---

# Claude Setup Maintenance

## Goal

Keep the Claude Code setup useful for long-running work: concise root memory, explicit routing, project-owned conventions, deterministic hooks, and concrete verification commands.

## Required flow

1. Inspect `CLAUDE.md`, the relevant `.claude/` files, their consumers, and recent configuration
   history. Read `docs/guides/claude-code-setup.md` when changing the layer model, permissions,
   routing, or lifecycle rather than correcting one local fact.
2. Identify one authoritative owner before editing:
   - `CLAUDE.md` for crucial, broadly applicable facts or instructions Claude cannot infer
   - `.claude/rules/` for always-on or path-scoped rules
   - `.claude/skills/` for repeatable workflows and subsystem conventions
   - `.claude/agents/` for reusable read-only or delegated specialists
   - `.claude/commands/` for manual slash-command affordances
   - `.claude/hooks/` for fast deterministic side effects or reminders
   - `docs/guides/` for longer reference material
3. Keep root memory small. Do not use it to index `.claude/`; repair descriptions, path scope,
   placement, preloaded skills, or reference ownership when native discovery is weak.
4. Prefer repo-owned wrappers for repeated commands instead of documenting ad-hoc raw invocations.
5. Keep checked-in `.claude/settings.json` safe for shared use. Put personal speed or permission preferences in local-only guidance.
6. Verify changed scripts or hooks with the smallest meaningful command.
7. Update the owning reference and `docs/guides/important-code.md` only when its architecture map changes.
8. For a policy change, record the approved decision in a task or guide; for a documentation-only correction, update the smallest accurate surface.

## Design rules

- Skill descriptions should contain ordinary trigger language, exclusions where overlap is likely,
  and enough specificity for automatic routing.
- Rules should say what is required or forbidden, not merely "prefer consistency."
- Read-only agents must use `permissionMode: plan`; prose alone is not enforcement.
- Hooks must be fast, deterministic, and event-shaped. Do not use prompt hooks to duplicate routing
  that skill metadata or rule scope already provides.
- Commands should be manual affordances; automatic routing belongs in skills and rules.
- External plugins or specialist skills are optional overlays unless explicitly adopted as project policy.

## Do not

- Do not turn scattered markdown into a parallel rules system.
- Do not force-load broad reference documents for every task.
- Do not add broad blocking hooks for normal development actions.
- Do not vendor external Claude plugins into the repo without explicit approval.
- Do not add bypass-permissions settings to shared project config.
- Do not grant broad shared shell access merely to reduce prompts; put personal speed preferences in local configuration.

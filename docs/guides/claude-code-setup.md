# Claude Code Setup

This is the design reference for the repository's Claude Code control plane. It explains ownership;
the components themselves provide routing through their native metadata and scope.

## Layer ownership

- `CLAUDE.md` contains only crucial repository-wide facts, invariants, approval boundaries, and
  non-obvious verification entry points. It is loaded in full on every turn and must not index the
  rest of the configuration.
- Unscoped rules contain standing policy worth loading in every session. Path-scoped rules contain
  standing policy that becomes relevant only after Claude reads a matching file.
- Skills own repeatable task-shaped workflows. Their descriptions use ordinary request language,
  name likely exclusions, and make safe workflows automatically model-invocable.
- Agents own bounded delegated jobs. Discovery and review agents run with `permissionMode: plan`;
  a prose request to stay read-only is not an enforcement boundary.
- Commands are manual affordances when invocation itself is a user decision.
- References contain nuance needed by one or more owning skills or scoped rules. They are not a
  parallel instruction system and are not force-loaded as a startup ritual.
- Hooks are reserved for deterministic event-shaped side effects that cannot be expressed through
  native routing or ordinary verification. A hook must not repeat skill or rule prose on every
  prompt.
- Shared settings contain team policy, not personal speed preferences. Keep convenience allows in
  `.claude/settings.local.json`; keep sensitive-path and destructive-command denies shared.

## Routing standard

Claude Code loads root memory and unscoped rules at startup, path-scoped rules when matching files
are read, and skill descriptions so the model can select a skill from normal task language. Design
for that behavior directly:

1. Put common trigger phrases and exclusions in skill and agent descriptions.
2. Put file- or subtree-specific standing policy in a scoped rule.
3. Preload a skill into an agent only when every invocation needs its full content.
4. Give broad references one clear owning skill or rule; load only the relevant section.
5. Treat repeated missed routing as a metadata or scope defect. Do not compensate with a root index
   or prompt-injection hook.

Model-invocable release guidance may load only after an explicit release-shaped user request. Skill
selection is not permission to perform an external write: the workflow must still classify the
requested effect and resolve material ambiguity before acting.

## Context and parallelism

Use direct compiler, test, and repository-search evidence first. Delegate only when a bounded
discovery or review result would keep a large amount of disposable detail out of the main context,
or when genuinely independent ownership makes parallel work cheaper. Subagents do not share live
reasoning. Writers need isolated checkouts and non-overlapping ownership; read-only reviewers use
plan mode.

Auto memory is machine-local and can retain useful repository learnings, but it is not team policy.
Durable conventions belong in version-controlled rules, skills, tests, scripts, or references.

## Maintenance and verification

For every control-plane change:

1. Check repository evidence and recent configuration history before deciding policy.
2. Update one authoritative owner; remove stale duplicates.
3. Validate JSON, YAML frontmatter, referenced paths, hook syntax, and executable bits as applicable.
4. Run `claude doctor` against the project settings.
5. Use `/skill-doctor` in an authenticated interactive session to find unused or context-expensive
   skills; use `/context`, `/memory`, `/permissions`, and `/hooks` to inspect what actually loaded.
6. Review the diff for accidental policy changes and record exact evidence in the task file.

Claude Code changes quickly. Verify behavior against the current official documentation for
[memory and rules](https://code.claude.com/docs/en/memory),
[skills](https://code.claude.com/docs/en/skills),
[subagents](https://code.claude.com/docs/en/sub-agents),
[permissions](https://code.claude.com/docs/en/permissions), and
[hooks](https://code.claude.com/docs/en/hooks) rather than preserving a version-specific workaround.

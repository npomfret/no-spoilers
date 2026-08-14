# Claude Code Control Plane

## Goal

Make the checked-in Claude Code setup a safe, discoverable control plane for a long-lived native Swift product.

## Constraints

- Keep `CLAUDE.md` concise and route detailed policy to rules, skills, agents, and guides.
- Preserve the spoiler-free product contract: results must never enter the product model, storage, UI, tests, or fixtures.
- Do not add dependencies or external plugins.
- Shared permissions must be safe by default; personal convenience belongs in local configuration.

## Approved pattern

- Rules hold standing or path-scoped constraints.
- Skills hold repeatable task workflows with clear intent-based descriptions.
- Hooks provide short deterministic context or formatting only.
- Guides hold longer evidence and operational reference.

## Plan

- [x] Audit the current control plane, product architecture, and Claude Code research.
- [x] Add missing spoiler-safety and delivery workflow surfaces.
- [x] Tighten shared settings and task/configuration routing.
- [x] Validate JSON, shell hooks, front matter, and routing references.

## Verification

- PASS — `python3 -m json.tool .claude/settings.json`
- PASS — `bash -n .claude/hooks/remind-standards.sh .claude/hooks/run-format-from-root.sh .claude/hooks/session-routing-context.sh`
- PASS — executed the session-start and prompt-submit hooks, then ran `git diff --check` and repository routing/permission searches.

## Risks

- Permission policy must not silently grant broad shell access in shared config.
- Delivery tooling has separate read-only and write paths; the workflow must preserve that boundary.

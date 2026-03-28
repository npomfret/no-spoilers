# General Guide

Canonical cross-cutting policy for this repo.

## Core principles

- Keep changes small, scoped, and reversible unless the task explicitly calls for a broader refactor.
- Never guess commands, targets, schemes, bundle identifiers, paths, or environment values.
- Never claim completion without command evidence.
- Prefer strong shared boundaries over ad-hoc local fixes.
- Heavy refactoring is preferred over leaving duplicate or inconsistent implementations in place.

## Pattern governance

- One concern should have one approved implementation pattern.
- Before editing, identify the nearest existing pattern that already solves the same concern.
- Reuse or refactor that pattern instead of adding another implementation style.
- If no approved pattern fits, stop and propose the new standard before implementing it.
- Treat duplicate helpers, parallel flows, and silent architecture drift as correctness issues.

## Change discipline

- Do exactly what was requested; clarify ambiguities instead of guessing.
- Do not add hidden fallbacks, hacks, or speculative abstractions.
- Encapsulate repeated behavior behind shared boundaries.
- Delete dead code, stale comments, and superseded variants when refactoring makes them obsolete.

## Workflow conventions

- Use task files in `tasks/` for substantial multi-step work.
- Keep task files current as plans and verification change.
- Prefer project skills and agents for repeatable workflows instead of ad-hoc prompting.

## Related guides

- `@docs/guides/workflows-and-tasks.md`
- `@docs/guides/important-code.md`
- `@docs/guides/swift-patterns.md`
- `@docs/guides/building.md`
- `@docs/guides/testing.md`

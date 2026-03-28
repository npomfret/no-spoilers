---
description: Core repo-wide engineering rules for all work.
---

# Core Rules

- Treat `.claude/skills/`, `.claude/agents/`, and `.claude/rules/` as the primary Claude Code control plane for this repo.
- Read `docs/guides/general.md`, `docs/guides/workflows-and-tasks.md`, and `docs/guides/important-code.md` before substantial work.
- Load `pattern-governance-reference` for substantial work, refactors, reviews, or any task where multiple implementations are possible.
- Read the actual target files before making design, implementation, or review claims.
- Verify concrete repo facts before acting. Do not invent commands, scripts, paths, targets, schemes, bundle identifiers, entitlement names, or environment defaults.
- For substantial work, identify the affected targets, packages, tests, platforms, and ownership boundaries first.
- Prefer the established local pattern for the same outcome. If none exists yet, propose the new pattern explicitly before spreading it across the codebase.
- If a shared abstraction almost fits, refactor it instead of creating a variant beside it.
- Remove duplication instead of creating parallel implementations for the same concern.
- Heavy refactoring is preferred over leaving inconsistent implementations in place.
- Treat duplicate helpers, parallel flows, alternate architectures, and silent pattern drift as correctness issues.
- Encapsulate repeated behavior behind shared boundaries instead of scattering logic across call sites.
- Keep changes small, scoped, and reversible unless the task explicitly calls for a larger refactor.
- Ask before destructive actions or high-risk ambiguity.
- Never revert or overwrite unrelated user changes.
- Never claim completion without direct command evidence.

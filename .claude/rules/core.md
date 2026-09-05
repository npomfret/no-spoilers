---
description: Repository-wide engineering constraints that apply to every task.
---

# Core Rules

- Read the actual target files before making design, implementation, or review claims.
- Verify concrete repo facts before acting. Do not invent commands, scripts, paths, targets, schemes, bundle identifiers, entitlement names, or environment defaults.
- For substantial work, identify the affected targets, packages, tests, platforms, and ownership boundaries first.
- Audit upstream, downstream, and lateral implementations before editing non-trivial code.
- Refactor for readiness before adding behavior when the current structure cannot cleanly host the requested change.
- Prefer the established local pattern for the same outcome. If none exists, describe the gap and obtain approval before creating one.
- If a shared abstraction almost fits, refactor it instead of creating a variant beside it.
- Remove duplication instead of creating parallel implementations for the same concern.
- Treat duplicate helpers, parallel flows, alternate architectures, and silent pattern drift as correctness issues.
- Encapsulate repeated behavior behind shared boundaries instead of scattering logic across call sites.
- Keep changes small, scoped, and reversible unless the task explicitly calls for a larger refactor.
- Do not add speculative compatibility, abstraction, or fallback behavior for requirements the project does not have.
- Never revert or overwrite unrelated user changes.
- Keep handoff concise and outcome-first: changed behavior, exact verification, decisions, and residual risk.

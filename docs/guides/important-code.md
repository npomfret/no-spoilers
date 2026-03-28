# Important Code Guide

This guide maps the current control plane and the places that define repo standards.

## Current control plane

1. `CLAUDE.md` — root routing layer and startup context.
2. `.claude/rules/core.md` — repo-wide engineering and pattern-governance rules.
3. `.claude/rules/apple-platforms.md` — Apple-platform implementation rules.
4. `.claude/rules/testing.md` — verification and evidence rules.
5. `.claude/skills/pattern-governance-reference/SKILL.md` — mandatory pattern-first reference for substantial work.
6. `.claude/skills/implement-apple-change/SKILL.md` — implementation/refactor workflow for Swift and Apple-platform code.
7. `.claude/skills/review-working-tree/SKILL.md` — read-only correctness and pattern-drift review workflow.
8. `.claude/agents/codebase-explorer.md` — discovery and pattern lookup specialist.
9. `.claude/agents/pattern-compliance-reviewer.md` — read-only duplication and pattern-drift specialist.

## Current repo state

- The application architecture is still forming.
- Until the main app code exists, the control plane above is the authoritative source for implementation standards.
- As real Swift targets, packages, modules, and app entry points land, this guide should be updated to map the actual codebase.

## Update rule

When core architecture or canonical patterns change, update this guide so Claude has an accurate map of the approved structure.

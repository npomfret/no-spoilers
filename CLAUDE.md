# No Spoilers

Use Claude Code routing surfaces first:

- skills in `.claude/skills/`
- agents in `.claude/agents/`
- rules in `.claude/rules/`
- hooks in `.claude/settings.json`

Keep this file small. Put detailed guidance in rules or skills instead of growing always-on memory.

## Always-On Reading

Read these first for every task:

- `@docs/guides/general.md`
- `@docs/guides/workflows-and-tasks.md`
- `@docs/guides/important-code.md`

Read these when the task touches their area:

- `@docs/guides/swift-patterns.md`
- `@docs/guides/building.md`
- `@docs/guides/testing.md`
- `@docs/brand.md` — when touching colours, typography, or visual style in any target or on the web

## Project state

- This repo is becoming a Swift project for macOS and iOS.
- Verify the real project structure before assuming anything about targets, schemes, packages, scripts, entitlements, or build commands.
- The project should converge on a small number of strong patterns. Claude must refactor toward those patterns, not add parallel implementations.

## Fail fast

Missing data that should never be missing is a programming error, not a runtime condition to handle gracefully. Code must crash immediately and loudly rather than silently producing wrong output.

- Use `precondition`, force-unwrap (`!`), or `fatalError` for data or resources that must always be present.
- Never use `?? defaultValue` to paper over a missing resource or unexpected nil — crash instead.
- Never return a sentinel value (empty string, placeholder image, zero) to signal a missing resource — crash instead.
- Optional return types are only appropriate when absence is a valid, expected state (e.g. no upcoming session). They must never be used to silently swallow errors.

## Hard constraints

- Do not invent commands, scripts, paths, targets, schemes, bundle identifiers, Info.plist keys, entitlement names, environment variables, or defaults. Read the repo first.
- For non-trivial feature work, audit the relevant code paths first, identify the approved pattern, refactor the area into a clean host for the change when needed, then implement.
- Never introduce a new dependency, abstraction family, file layout, naming convention, or implementation pattern without explicit approval when no repo standard already exists.
- Prefer the established local pattern for the same outcome. If no approved pattern exists yet, stop and propose the new pattern before implementing it broadly.
- Heavy refactoring is preferred over leaving duplicate or inconsistent implementations in place.
- Encapsulate behavior behind shared boundaries when the same concern appears more than once.
- Duplicate helpers, variant architectures, and one-off implementation styles are correctness problems, not style issues.
- Ask before destructive actions or high-risk ambiguity.
- Never revert, overwrite, or clean up unrelated user changes.
- Keep changes small and scoped unless the task explicitly asks for a broader refactor.
- Never claim completion without command evidence.

## Routing

- Load `pattern-governance-reference` for substantial work, refactors, or any task where multiple implementations are possible.
- Use `feature-workflow` for non-trivial features, bug fixes, behavior changes, and refactors.
- Use `claude-setup-maintenance` when changing `CLAUDE.md`, `.claude/`, Claude-facing guides, hooks, commands, or verification wrappers.
- Use `implement-apple-change` for Swift, SwiftUI, UIKit, AppKit, project-structure, or Apple-platform refactors and implementation work.
- Use `build-verify` for compile, type, build, or toolchain confidence.
- Use `test-changes` for behavior-risk verification after a fix or behavior change.
- Use `review-working-tree` for read-only audits of correctness, regressions, duplication, and missing verification.
- Use `/comment` to draft a commit message for the current changeset.
- Use `/merge` for the controlled linear-history update workflow.
- Use `/sanity-check` for an explicit read-only compliance and risk pass.
- Load `.claude/rules/core.md` for all work.
- Load `.claude/rules/apple-platforms.md` when the task touches Swift, Xcode, Apple-platform UI, Info.plist, entitlements, packages, or project configuration.
- Load `.claude/rules/testing.md` before verification work.

## gstack

- Use `/browse` from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.
- Available gstack skills: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`

## Working style

- For substantial work, identify the affected targets, packages, tests, platforms, and the nearest approved pattern before editing.
- Read the actual files involved before making design or implementation claims.
- Use `codebase-explorer` for broad discovery and pattern lookup before large edits.
- Use `pattern-compliance-reviewer` for read-only drift and duplication checks when the change surface is large or architectural.
- Prefer CLI verification supported by the repo. If the repo has not standardized its build or test wrappers yet, verify the real entry points first and then use the smallest meaningful scope.

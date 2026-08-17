# No Spoilers

Spoiler-free Formula 1 weekend timelines for iOS, macOS, and WidgetKit. Keep this root contract short; detailed policy belongs in `.claude/rules/`, `.claude/skills/`, agents, and `docs/guides/`.

## Non-negotiables

- The spoiler-free guarantee is architectural: results, standings, driver news, and result-shaped fields must never enter models, storage, fixtures, UI, logs, or tests. Load `.claude/rules/spoiler-safety.md` for product-code work.
- Read the actual repository before making claims. Do not invent commands, targets, schemes, paths, bundle IDs, entitlement keys, or defaults.
- For non-trivial work: audit upstream, downstream, lateral precedent, and tests; refactor for the current requirement; then implement and verify.
- Reuse the approved pattern or stop and ask before adding a dependency, abstraction, file layout, naming convention, or second implementation style.
- Fail loudly for impossible missing data. Never hide it with defaults, sentinels, or optionality.
- Do not overwrite unrelated changes or take destructive actions without approval. Never claim completion without command evidence.
- No branches. Work on main only unless told otherwise.

## Product map

- `NoSpoilersCore/` — shared schedule-only domain, fetching, caching, and shared views.
- `NoSpoilers/` — iOS app, WidgetKit extension, macOS menu-bar app, and Xcode Cloud hook.
- `scripts/` — canonical verification, release, screenshot, and App Store Connect tooling.

## Routing

- Always read `docs/guides/general.md`, `workflows-and-tasks.md`, and `important-code.md` first.
- `pattern-governance-reference` — substantial work, refactors, or competing implementations.
- `feature-workflow` — non-trivial feature, fix, behavior change, or refactor; maintain `tasks/` for substantial work.
- `implement-apple-change` — Swift, SwiftUI, AppKit, WidgetKit, Xcode, or Apple-platform refactors.
- `build-verify` / `test-changes` — compile confidence / changed-behavior confidence.
- `review-working-tree` — read-only correctness and drift review.
- `claude-setup-maintenance` — Claude instructions, rules, skills, agents, hooks, commands, guides, or verification wrappers.
- `release-and-delivery` — explicit release, TestFlight, App Store Connect, Xcode Cloud, or screenshot work.

Load `docs/guides/swift-patterns.md`, `building.md`, `testing.md`, or `brand.md` when their area is touched. Load the applicable rules before editing. Use `codebase-explorer` for broad discovery and `pattern-compliance-reviewer` for large read-only drift audits.

## Canonical commands

- Shared tests: `scripts/verify-core-tests.sh`
- macOS build: `scripts/verify-mac-build.sh`
- iOS build: `scripts/verify-ios-build.sh`
- Widget build: `scripts/verify-widget-build.sh`

Use `/comment`, `/merge`, and `/sanity-check` only when explicitly requested. Use gstack `/browse` for web browsing; never use `mcp__claude-in-chrome__*`.

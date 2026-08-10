# Important Code Guide

This guide maps the current control plane and the places that define repo standards.

## Current control plane

1. `CLAUDE.md` — root routing layer and startup context.
2. `.claude/rules/core.md` — repo-wide engineering and pattern-governance rules.
3. `.claude/rules/apple-platforms.md` — Apple-platform implementation rules.
4. `.claude/rules/testing.md` — verification and evidence rules.
5. `.claude/skills/pattern-governance-reference/SKILL.md` — mandatory pattern-first reference for substantial work.
6. `.claude/skills/feature-workflow/SKILL.md` — audit-first workflow for non-trivial features, bug fixes, behavior changes, and refactors.
7. `.claude/skills/implement-apple-change/SKILL.md` — implementation/refactor workflow for Swift and Apple-platform code.
8. `.claude/skills/build-verify/SKILL.md` — compile, build, and toolchain verification workflow.
9. `.claude/skills/test-changes/SKILL.md` — targeted behavior-risk verification workflow.
10. `.claude/skills/review-working-tree/SKILL.md` — read-only correctness and pattern-drift review workflow.
11. `.claude/skills/claude-setup-maintenance/SKILL.md` — workflow for maintaining Claude Code instructions and automation.
12. `.claude/agents/codebase-explorer.md` — discovery and pattern lookup specialist.
13. `.claude/agents/pattern-compliance-reviewer.md` — read-only duplication and pattern-drift specialist.
14. `docs/guides/claude-code-setup.md` — longer reference for the Claude Code control plane.
15. `scripts/verify-core-tests.sh` — canonical Swift package test wrapper.
16. `scripts/verify-mac-build.sh`, `scripts/verify-ios-build.sh`, `scripts/verify-widget-build.sh` — canonical Xcode build wrappers.
17. `scripts/release.sh` — the single release engine; `scripts/ship-*.sh` and `.github/workflows/release.yml` are wrappers over it.
18. `NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh` — the only Xcode Cloud hook: the test gate and the build-number stamp for the iOS TestFlight path. See `docs/guides/building.md`.
19. `scripts/appstore_status.py` — reads App Store Connect and TestFlight, writes nothing. Holds everything both scripts share: ES256 token signing (`token`, `key_path`), the app lookup (`find_app`), and build selection (`builds_path`, `platform_builds`, `live_builds`, `newest_build`, `groups_holding`). Newest means most recently uploaded, never the highest number — define it once here, not twice.
20. `scripts/testflight_distribute.py` — the only Python here that writes to App Store Connect: hands the newest iOS build to a tester group and makes that build's *What to Test* note describe it. It imports 19's selection helpers rather than repeating them, so the report and the command cannot disagree about which build is newest. The read/write split between 19 and 20 is deliberate and carries a key boundary with it.

## Current repo state

- The application architecture is still forming.
- `NoSpoilersCore` is the shared Swift package for domain logic and tests.
- `NoSpoilersApp`, `NoSpoilersWidgetExtension`, and `NoSpoilersMac` are the Xcode project targets.
- The shared `NoSpoilers` scheme currently builds the macOS app; the iOS wrapper uses the `NoSpoilersApp` scheme when present in shared schemes.
- The control plane above is the authoritative source for implementation standards.

## Update rule

When core architecture or canonical patterns change, update this guide so Claude has an accurate map of the approved structure.

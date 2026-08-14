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
14. `.claude/rules/spoiler-safety.md` — path-scoped enforcement of the product's schedule-only, no-results contract.
15. `.claude/agents/spoiler-safety-reviewer.md` — read-only audit specialist for spoiler-risk changes.
16. `.claude/skills/release-and-delivery/SKILL.md` — explicit-only workflow for releases, TestFlight, Xcode Cloud, App Store Connect, and listing screenshots.
17. `docs/guides/claude-code-setup.md` — longer reference for the Claude Code control plane.
18. `scripts/verify-core-tests.sh` — canonical Swift package test wrapper.
19. `scripts/verify-mac-build.sh`, `scripts/verify-ios-build.sh`, `scripts/verify-widget-build.sh` — canonical Xcode build wrappers.
20. `scripts/release.sh` — the single release engine; `scripts/ship-*.sh` are the only wrappers over it, and they run on your machine. There is no CI release path: `.github/workflows/release.yml` was deleted on 2026-08-12 having never once succeeded.
21. `NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh` — the only Xcode Cloud hook: the test gate and the build-number stamp for the iOS TestFlight path. See `docs/guides/building.md`.
22. `scripts/appstore_status.py` — reads App Store Connect and TestFlight, writes nothing. Holds everything the Python here shares: ES256 token signing (`token`, `key_path`), the app lookup (`find_app`), build selection (`builds_path`, `platform_builds`, `live_builds`, `newest_build`, `groups_holding`), and the Xcode Cloud product lookup (`ci_products`, `select_ci_product`, `find_ci_product`). Newest means most recently uploaded, never the highest number — define it once here, not twice.
23. `scripts/testflight_distribute.py` — the only Python here that writes to App Store Connect: hands the newest iOS build to a tester group and makes that build's *What to Test* note describe it. It imports 22's selection helpers rather than repeating them, so the report and the command cannot disagree about which build is newest. The read/write split between 22 and 23 is deliberate and carries a key boundary with it.
24. `scripts/ci_health.py` — read-only check that Xcode Cloud is wired to the right projects, and the thing to run immediately after Integrate → Create Workflow. Two projects share this Apple team, and that wizard has three times seized the other one's product; see the Continuous delivery section of `docs/guides/building.md`. It asserts non-interference in both directions — no product of ours attached to another repository, and **no product of theirs attached to ours**.

25. `scripts/screenshots.py` — the only thing that produces App Store listing screenshots. Seeds a fixture into the App Group container, places the widget at a chosen family, boots and captures. It writes to a simulator and to `tmp/screenshots/` and **never to App Store Connect**, which is what keeps it outside the read/write split above; uploading is 23's raw `patch` or the bot. Stdlib-only like the rest of the Python here. **Its central rule is that the app is never launched** — `ScheduleStore.refresh()` calls `cache.save(...)` unconditionally without consulting `isFresh`, so launching the app to "make it pick up the fixture" is what destroys the fixture. See `docs/guides/building.md` and the script's own docstring, which is the long-form reference.

**Never identify an Xcode Cloud product by name or by a recorded id.** The name is the field the fault rewrites, and the id does not survive a deletion — a constant id took 23 down entirely, dry run included. `find_ci_product` matches on the app the product builds, which is the field the fault strips rather than forges, so a seized record matches nothing instead of matching wrongly.

## Current repo state

- The application architecture is still forming.
- `NoSpoilersCore` is the shared Swift package for domain logic and tests.
- `NoSpoilersApp`, `NoSpoilersWidgetExtension`, and `NoSpoilersMac` are the Xcode project targets.
- The shared `NoSpoilers` scheme currently builds the macOS app; the iOS wrapper uses the `NoSpoilersApp` scheme when present in shared schemes.
- The control plane above is the authoritative source for implementation standards.

## Update rule

When core architecture or canonical patterns change, update this guide so Claude has an accurate map of the approved structure.

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
22. `scripts/appstore_status.py` — reads App Store Connect and TestFlight for **both platforms**, writes nothing. Holds everything the Python here shares: ES256 token signing (`token`, `key_path`), the app lookup (`find_app`), build selection (`builds_path`, `platform_builds`, `live_builds`, `newest_build`, `groups_holding`), the platform pair (`PLATFORM_FLAGS`, `TESTFLIGHT_PLATFORMS`), and the Xcode Cloud product lookup (`ci_products`, `select_ci_product`, `find_ci_product`). Newest means most recently uploaded, never the highest number — define it once here, not twice.
23. `scripts/testflight_distribute.py` — the only Python here that writes to App Store Connect: hands one platform's newest build to a tester group and makes that build's *What to Test* note describe it — from the Xcode Cloud run that produced it, or, for a locally shipped build that no run produced, from the `bump to vX.Y.Z (build N)` commit `release.sh` writes. It imports 22's selection helpers rather than repeating them, so the report and the command cannot disagree about which build is newest, and its `--platform` choices **are** 22's `PLATFORM_FLAGS`, so a platform it can deliver to is one the report covers. The read/write split between 22 and 23 is deliberate and carries a key boundary with it.
24. `scripts/ci_health.py` — read-only check that Xcode Cloud is wired to the right projects, and the thing to run immediately after Integrate → Create Workflow. Two projects share this Apple team, and that wizard has three times seized the other one's product; see the Continuous delivery section of `docs/guides/building.md`. It asserts non-interference in both directions — no product of ours attached to another repository, and **no product of theirs attached to ours**.

25. `scripts/screenshots.py` — the only thing that produces App Store listing screenshots. Seeds a fixture into the App Group container, places the widget at a chosen family, boots and captures. It writes to a simulator and to `tmp/screenshots/` and **never to App Store Connect**, which is what keeps it outside the read/write split above; uploading is 23's raw `patch` or the bot. Stdlib-only like the rest of the Python here. **Its central rule is that the app is never launched** — `ScheduleStore.refresh()` fetches and calls `cache.save(...)` unconditionally, with no freshness check of any kind to stop it, so launching the app to "make it pick up the fixture" is what destroys the fixture. See `docs/guides/building.md` and the script's own docstring, which is the long-form reference.

26. `docs/guides/brand.md` — **the cross-platform token spec**, and the authority for any visual decision. Every token with both its bindings, and an explicit note on the Swift-only families. Moved here from `docs/brand.md` on 2026-08-17, where it had been a colour-only document that the code had drifted from.
27. `NoSpoilersCore/Sources/NoSpoilersCore/Theme.swift` — the Swift binding of 26. `Palette`, `Canvas`, `Typography`, `Space`, `Radius`, `Motion`, `Icon`, plus the per-component families (`Card`, `MessageCard`, `Badge`, `Row`, `NextUp`, `Header`, `ScreenHeader`, `SectionLabel`, `DetailRow`). **`Theme.Canvas` is the only size axis** — `iosApp`, `macPopover`, `widgetSmall`, `widgetMedium`, `widgetLarge`. Do not add a second one; a `NoSpoilersCardDensity` and a `compact: Bool` both existed beside it and both are deleted. Its doc comments carry the reasoning behind each value and are worth reading before changing one.
28. `NoSpoilersCore/Sources/NoSpoilersCore/BrandPalette.swift` — the only place a colour hex lives on the Swift side. `Theme.Palette` names roles that point at it. **`signalRed` is also transcribed into three `AccentColor.colorset` JSON files**, because an asset catalog cannot reference Swift and nothing will fail to compile if they drift.
29. `NoSpoilersCore/Sources/NoSpoilersCore/SharedChrome.swift` — the shared components every target draws, and the boundary duplicated views converge onto rather than being reimplemented beside. A second implementation of anything here is a correctness issue, not a style one.
30. `scripts/alerts_check.py` — the only way to see whether the iOS session alerts reach the OS. Launches the app on the simulator and streams the `alerts` log channel back, reporting planned against pending. **Imports its device helpers from 25** rather than repeating them, the same way 23 imports 22's: two scripts that disagree about which simulator they mean is the failure this prevents. Its `--push` sample copy is *extracted from* `NoSpoilers/NoSpoilers/Strings.swift`, never transcribed — a second copy of notification wording would drift and still screenshot convincingly. It cannot fire one of our own alerts on demand, and its docstring carries the reason: a seeded fixture does not survive `ScheduleStore.refresh()`, and the seam that would fix it is 25's declined launch-argument trade.
31. `docs/styles.css` — the CSS binding of 26, shared by `docs/index.html` and `docs/privacy.html`. Neither page may carry its own `:root` block, a raw hex, or a raw radius.

**Never identify an Xcode Cloud product by name or by a recorded id.** The name is the field the fault rewrites, and the id does not survive a deletion — a constant id took 23 down entirely, dry run included. `find_ci_product` matches on the app the product builds, which is the field the fault strips rather than forges, so a seized record matches nothing instead of matching wrongly.

## Current repo state

- The application architecture is still forming.
- `NoSpoilersCore` is the shared Swift package for domain logic and tests.
- `NoSpoilersApp`, `NoSpoilersWidgetExtension`, and `NoSpoilersMac` are the Xcode project targets.
- The shared `NoSpoilers` scheme currently builds the macOS app; the iOS wrapper uses the `NoSpoilersApp` scheme when present in shared schemes.
- The control plane above is the authoritative source for implementation standards.

## Update rule

When core architecture or canonical patterns change, update this guide so Claude has an accurate map of the approved structure.

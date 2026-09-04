# No Spoilers

Spoiler-free Formula 1 weekend timelines for iOS, macOS, and WidgetKit. Keep this root contract short; detailed policy belongs in `.claude/rules/`, `.claude/skills/`, agents, and `docs/guides/`.

## Project status

The desktop app, which is largely a menu bar widget has been accepted by the Apple App Store and is live.

The iPhone iOS app has not been accepted in the Apple App Store yet. The review process is difficult to pass but it is being worked on.  This is our priority.

We have a build on a shared teamcity instance, read about it (here)[https://github.com/npomfret/snowmonkey-proxy-common/blob/main/docs/TEAMCITY-AGENTS.md]. You have programitic admin access.

App Review state (Resolution Center threads, rejections, the draft reply and sending it) is reachable only through the sibling repo [appstoreconnect-bot](/Users/nickpomfret/projects/appstoreconnect-bot) — `node dist/cli.js report 6761343835` there. Its `tmp/curl.txt` is a request copied from the browser purely as a way of getting the session cookie into a file; nothing else is read from it, so the app id is always passed, and ours is `6761343835` (`OURS` in `scripts/appstore_status.py`). `appstore_status.py` is the public-API half and cannot read the conversation; attaching a build or writing listing copy stays with `scripts/appstore_listing.py`.

## Non-negotiables

- This is a Formula 1 app. But we must never use that word of F1 or any "owned" or copyrights terms or images.
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
- `feature-workflow` — non-trivial feature, fix, behavior change, or refactor.
- `implement-apple-change` — Swift, SwiftUI, AppKit, WidgetKit, Xcode, or Apple-platform refactors.
- `build-verify` / `test-changes` — compile confidence / changed-behavior confidence.
- `review-working-tree` — read-only correctness and drift review.
- `claude-setup-maintenance` — Claude instructions, rules, skills, agents, hooks, commands, guides, or verification wrappers.
- `release-and-delivery` — explicit release, TestFlight, App Store Connect, Xcode Cloud, or screenshot work.

Load `docs/guides/swift-patterns.md`, `building.md`, `testing.md`, or `brand.md` (the cross-platform token spec) when their area is touched. Load the applicable rules before editing. Use `codebase-explorer` for broad discovery and `pattern-compliance-reviewer` for large read-only drift audits.

## Canonical commands

- Shared tests: `scripts/verify-core-tests.sh`
- macOS build: `scripts/verify-mac-build.sh`
- iOS build: `scripts/verify-ios-build.sh`
- Widget build: `scripts/verify-widget-build.sh`

## Simulators

- **Always target this project's own named simulators, `NoSpoilers-iPhone` and `NoSpoilers-iPad`.**
  Other projects run on this machine and share the stock simulators; capturing screenshots seeds an
  App Group fixture, reinstalls the app, and reboots the device, so using a stock simulator corrupts
  their state and lets theirs corrupt ours.
- `NoSpoilers-iPad` exists because `.systemExtraLarge` has no iPhone slot — SpringBoard drops the
  entry on one — so that family can only be built, placed or photographed on an iPad.
- **`NoSpoilers-iPhone-65` and `NoSpoilers-iPad-129` exist because the other two cannot fill the
  listing's slots.** App Store Connect holds `APP_IPHONE_65` (1242x2688) and
  `APP_IPAD_PRO_3GEN_129` (2048x2732) for this app, and `NoSpoilers-iPhone` renders 1206x2622
  while `NoSpoilers-iPad` renders 2064x2752 — both refused. Added 2026-08-25, after checking the
  display types on the record rather than trusting a doc comment. Use these two for anything
  destined for the listing and the first two for everything else.
- **A freshly created simulator drops the widget from the Home Screen until the app has been
  launched once**, with `screenshots.py` reporting `SpringBoard dropped NoSpoilersWidget` and
  suggesting `supportedFamilies` — which is the wrong place to look. WidgetKit has not registered
  the extension yet. Launch the app once, let it settle, terminate it, then capture; the script
  re-seeds the fixture afterwards, so the launch cannot leave real data in the picture.
- Never pass a bare stock device name (`iPhone 17`) or a raw UDID to `xcodebuild -destination` or
  `scripts/screenshots.py --device`.
- Recreate them if missing:
  `xcrun simctl create "NoSpoilers-iPhone" com.apple.CoreSimulator.SimDeviceType.iPhone-17 <runtime>`
  `xcrun simctl create "NoSpoilers-iPad" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB <runtime>`
  `xcrun simctl create "NoSpoilers-iPhone-65" com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max <runtime>`
  `xcrun simctl create "NoSpoilers-iPad-129" com.apple.CoreSimulator.SimDeviceType.iPad-Air-13-inch-M4 <runtime>`

Use `/comment`, `/merge`, and `/sanity-check` only when explicitly requested. Use `WebFetch` and `WebSearch` for web browsing; never use `mcp__claude-in-chrome__*`.

## Task files

A `tasks/` folder holds one markdown file per piece of work. This is our standard workflow and the wording is identical across all our projects. Task files are committed with the code.

### When a task file is required

- Always, for planned work.
- For unplanned work, whenever a reasonable-length commit message could not adequately describe the problem, the solution and the evidence. If a commit message is enough, no task file is needed.
- One file per piece of work. If an existing task already owns the work, update it instead of creating another.

### Naming and location

- `<slug>.md` inside a `tasks/` folder. The slug is a short imperative description in plain search terms, for example `fix-login-timeout.md` or `add-csv-export.md`. A numeric or stream prefix is fine where the project already uses one.
- A `tasks/` folder need not be at the repository root. Where a project is split into sub-projects, each may keep its own `tasks/` folder owning the work for its code, and a root `tasks/` then covers work that crosses sub-projects or concerns the repository itself. Put the file in the `tasks/` folder closest to the code it changes.
- Subfolders inside `tasks/` may group related work.
- Non-task documentation goes in `docs/`, not `tasks/`.

### What goes in a task file

A task file grows with the work. It may begin as nothing more than a bug report or a one-line feature request, and at that point it is complete. Add a section when the work produces something to put under it; never write a heading you have nothing to fill.

Only the issue is always present:

- The issue: the bug, feature, refactor or research question, and why it matters.
- Brainstorming: candidate approaches, including rejected ones and why they were rejected.
- The plan: the chosen solution, broken into steps or phases that each leave the system working, with observable success criteria.
- Tracking: current status, decisions and approvals, what has shipped, what remains, blockers, the exact verification run, and residual risk.

### Keeping it current

- A task file is a living working document, not a diary. Correct stale scope, plans and claims in place. Do not append a chronological log of changes of mind; git history records that.
- Update the task file in the same commit as the code it describes so status and implementation never drift.
- Mark a step complete only when the implementation exists and its verification has passed. If verification cannot run, leave the step open and record the exact blocker.

### Completion and deletion

- A task file is not an authority, and code and durable docs must never reference one.
- Usually nothing needs promoting before deletion. The work is the code, the tests are the evidence, and both stay. Delete the file.
- Occasionally a task reaches a conclusion the code cannot carry: a product or architecture decision, or an approach rejected for reasons worth not rediscovering. Move that to `docs/` first. This is the exception, not the rule.
- The commit that lands the last piece of work also updates the task file to its final state: what shipped, exact verification, remaining risk.
- Delete the completed task file in a separate follow-up commit, after that last piece of work is committed. Genuinely outstanding work moves to a new, narrower task file first.

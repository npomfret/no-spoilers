# No Spoilers

Native iPhone, macOS, and WidgetKit race-weekend timelines. Swift and SwiftUI with a shared
`NoSpoilersCore` package (iOS 17, macOS 14), Python App Store Connect tooling in `scripts/`, and
TeamCity (`.teamcity/`). Lifecycle: live. README.md records both apps on one App Store listing, the
iPhone app live since 2026-09-02, and releases tagged to v1.1.4.

- The spoiler-free guarantee is architectural. Product data may contain schedule identity,
  location, kind, and timing only; outcome-bearing data must never enter models, storage, fixtures,
  UI, logs, tests, or screenshots.
- Do not add series-owned names, marks, logos, or imagery to product or listing surfaces. Preserve
  the existing legally required trademark disclaimer.
- Reuse the established pattern. Ask before introducing a dependency, abstraction family, file
  layout, naming convention, or second implementation style.
- Fail loudly when required data is absent. Do not conceal impossible states with defaults,
  sentinels, or optionality.
- Do not take destructive actions without approval.
- Planned work and complex unplanned work require one current task file under `tasks/`; the
  lifecycle is the `task-files:task-files` skill.
- Releases, App Store Connect writes, review replies, and simulator mutation require explicit user
  intent. Inspect the owning script and current remote state immediately before acting.

Verification entry points:

- Shared behavior: `scripts/verify-core-tests.sh`
- Python tooling: `scripts/verify-python-selftests.sh`
- macOS: `scripts/verify-mac-build.sh`
- iPhone: `scripts/verify-ios-build.sh`
- Widget: `scripts/verify-widget-build.sh`

<!-- agent-standards:begin -->
## Shared agent guidance

Before starting work, read [Scope](.agents/agent-standards/guidance/scope.md), [Running commands](.agents/agent-standards/guidance/commands.md), [Git](.agents/agent-standards/guidance/git.md), [Review before commit](.agents/agent-standards/guidance/review.md).
Before code changes: [State and dependencies](.agents/agent-standards/guidance/dependencies.md); Before UI changes: [Interface text](.agents/agent-standards/guidance/interface-text.md); Before tests or timeout changes: [Test timeouts](.agents/agent-standards/guidance/test-timeouts.md).
Keep the shared checkout on its default branch. Use detached worktrees. Agents commit, fast-forward land and push their verified, reviewed work.
- Be concise: lead with the outcome; give only the detail needed to act or decide.
- Do the work properly and verify it; never trade correctness for speed or cost.
- When options exist, recommend the best technical solution first, even if costlier; state cheaper alternatives separately with their trade-offs.
Also read these always-on project rules before work: [core](.claude/rules/core.md).
In Codex, use native skills and specialists for equivalent Claude invocations; referenced `.claude/` files remain canonical project knowledge.

*Managed by `npomfret/agent-standards`; edit the shared sources there.*
<!-- agent-standards:end -->

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
- Reuse the established pattern. When a dependency, abstraction family, file layout, naming
  convention, or second implementation style is genuinely needed, decide, keep it minimal, and
  record the decision in the task file or your report.
- Fail loudly when required data is absent. Do not conceal impossible states with defaults,
  sentinels, or optionality.
- Local destructive actions (reset, clean, deleting files) are ordinary work; never delete remote or production data.
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
## Operating contract

*Managed by `npomfret/agent-standards`; detailed workflows are skills.*

- Scope: do what was asked plus the callers, tests and migrations it needs. Leave unrelated refactors, renames, cleanup, dependency bumps and docs for separate work; suggest them at the end. Add failure handling only for observed evidence. Ask when readings differ materially. Done means the behaviour works, verification passes, and you report evidence and blockers.
- Gates: only substantive failures block (types, broken behaviour, agreed rules). Cosmetics are autoformatted and never block commits, CI or reviews. Run tests, builds and type checks yourself; no test or lint hooks, and formatting hooks only when targeted at changed files.
- Other agents share the checkout. Stage only your files; never stash, discard, revert or commit their changes. The shared checkout stays on the default branch; isolate with `git worktree add --detach tmp/worktrees/<name> main`.
- Git: work is complete only when verified, reviewed commits are on the default branch and pushed (`git pull --rebase`, land with `git merge --ff-only`). Commit, land and push without asking. Repositories stay private.
- Significant work (behaviour, refactor, tests, config, tooling) is reviewed independently before commit by a project reviewer or `change-reviewer`; resolve every finding. Tests and review replace neither each other nor user approval.
- Substantial work needs a committed task file under `tasks/`.
- Run commands yourself unless they need the user's login, password, sudo, device or install. Reuse the project's scripts and `tmp/ad-hoc-scripts/`; put multi-step or quoted shell in a named script there. Hand the user one short command, else a script run as `! tmp/ad-hoc-scripts/<purpose>.sh`. Send long output to `tmp/logs/`; read it with `rg` and bounded excerpts; never paste whole logs.
- Secrets never go in source, arguments, output or logs, or the repo; they live in iCloud Drive, reached through gitignored `secrets/` links. Configuration comes only from explicitly supplied files, never environment, dotenv or ambient login.
- Code: construct dependencies at the entry point and inject them; no globals, singletons or hidden construction; immutable by default; structured logs with fixed labels that preserve error causes and stacks; no sleeps in tests. Raising any test timeout or limit needs the user's approval.

- Be concise: lead with the outcome; give only the detail needed to act or decide.
- Do the work properly and verify it; never trade correctness for speed or cost.
- When options exist, recommend the best technical solution first, even if costlier; state cheaper alternatives separately with their trade-offs.
- Fail fast: surface errors with their cause; never swallow, mask or silently fall back from them.
- Keep one canonical implementation: migrate callers and delete superseded code instead of adding shims or compatibility layers.
- Question unclear or unsound requests before acting on them; do not comply silently.
Also read these always-on project rules before work: [core](.claude/rules/core.md).
In Codex, use native skills and specialists for equivalent Claude invocations; referenced `.claude/` files remain canonical project knowledge.

*Managed by `npomfret/agent-standards`; edit the shared sources there.*
<!-- agent-standards:end -->

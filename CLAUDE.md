# No Spoilers

Native iPhone, macOS, and WidgetKit race-weekend timelines. The macOS app is live; iPhone App Store
acceptance is the current product priority.

- The spoiler-free guarantee is architectural. Product data may contain schedule identity,
  location, kind, and timing only; outcome-bearing data must never enter models, storage, fixtures,
  UI, logs, tests, or screenshots.
- Do not add series-owned names, marks, logos, or imagery to product or listing surfaces. Preserve
  the existing legally required trademark disclaimer.
- For non-trivial work, audit upstream callers, downstream effects, lateral precedent, and nearby
  tests before editing. Refactor the current area into a clean host for the requirement, then
  implement and verify.
- Reuse the established pattern. Ask before introducing a dependency, abstraction family, file
  layout, naming convention, or second implementation style.
- Fail loudly when required data is absent. Do not conceal impossible states with defaults,
  sentinels, or optionality.
- Preserve unrelated changes. Do not take destructive actions without approval, and do not claim
  completion without executed command evidence.
- Work on `main`; do not create branches unless explicitly asked.
- Planned work and complex unplanned work require one current task file under `tasks/`; the
  lifecycle is the `task-files` skill.
- Releases, App Store Connect writes, review replies, and simulator mutation require explicit user
  intent. Inspect the owning script and current remote state immediately before acting.

Verification entry points:

- Shared behavior: `scripts/verify-core-tests.sh`
- Python tooling: `scripts/verify-python-selftests.sh`
- macOS: `scripts/verify-mac-build.sh`
- iPhone: `scripts/verify-ios-build.sh`
- Widget: `scripts/verify-widget-build.sh`

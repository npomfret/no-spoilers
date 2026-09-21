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
  lifecycle is the `task-files:task-files` skill.
- Releases, App Store Connect writes, review replies, and simulator mutation require explicit user
  intent. Inspect the owning script and current remote state immediately before acting.

Verification entry points:

- Shared behavior: `scripts/verify-core-tests.sh`
- Python tooling: `scripts/verify-python-selftests.sh`
- macOS: `scripts/verify-mac-build.sh`
- iPhone: `scripts/verify-ios-build.sh`
- Widget: `scripts/verify-widget-build.sh`

## Scope

Do what was asked, and nothing more. Work that was invented rather than requested is why a task never reaches an end.

### Never invent work

- Never invent a requirement. If the request does not state it and the project does not already require it, it is not a requirement.
- Never widen the scope of a change. The request sets the boundary; a related file, a neighbouring function or a second caller is outside it unless the change cannot work without them.
- Never start adjacent work you thought of yourself: a refactor you noticed, a test you would like to exist, a rename, a tidy-up, a dependency bump, a doc you would have written differently. "While I was in there" is not a reason.
- Never invent edge cases or failure scenarios. Before adding special handling, a fallback or a test for one, cite evidence that it exists: observed data, an actual incident, or a reproducible failure. "It could happen" is not evidence.
- Never treat a suggestion the user has not answered as approval. Silence is not yes, and neither is a suggestion you made yourself.

### Suggest instead

- Noticing work is not permission to do it. Say what you noticed in one line, and stop.
- Put suggestions at the end of the report, after what was actually done, and keep them separate from it so the two are never confused.
- One line each. A suggestion that needs a paragraph is a proposal, and a proposal is asked about before it is written, not after.
- Ask when the request is ambiguous. Do not resolve an ambiguity by building both sides, by building the larger one, or by building the one you find more interesting.

### Finish what was asked

This is not licence to stop early, and scope discipline is not an excuse for leaving something broken.

- A change is finished when what was asked works and has been verified — not when nothing more can be thought of, and not when the first part of it compiles.
- Work the change makes necessary is inside the scope, not outside it: a caller the new signature breaks, a test the change invalidates, a migration the schema now needs. Doing that is finishing the job, not expanding it.
- If the requested change cannot be made without work that was not requested, say so and wait. Do not do it silently, and do not abandon the request because of it.
- Report what was done and what was verified. Do not report intentions, or work you decided against.

*Generated from `npomfret/agent-standards`. Edit the standard there, not this copy.*

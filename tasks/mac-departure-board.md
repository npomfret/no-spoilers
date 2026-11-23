# Mac schedule departure board

The Mac popover should alternate each upcoming session's countdown with its local
start date and time. Flip timing text from top to bottom, one row at a time, without
moving the session name or changing the spoiler-free schedule contract.

## Scope and checked mechanisms

- Mac schedule: `WeekendPopoverView.sessionList`, `sessionRow`, `statusBadge` and
  the existing injected clock/visible lifetime. The menu bar title, next-weekend
  footer, iPhone and widgets keep their current behaviour.
- Shared row inventory: Mac `sessionRow`; iPhone `sessionCard` and `skeletonView`;
  widget `smallSessionRow` and `widgetSessionRow` (medium and large). All five source
  call sites supply a `Text?` detail. Generalise that existing detail slot to a
  `View?`, retaining its optionality and owning layout, rather than copying a row.
- `Strings.Schedule.sessionDateTime` already owns locale/time-zone formatting;
  extend it with a full-month presentation while preserving existing defaults.
- `SharedChrome.swift`, `Theme.Motion`, `DecemberDecorationView`, and searches for
  flip/rotation/alternation found no existing departure-board component or cycle.
  A sibling-workspace filename search found no applicable native component.
- Use one new reusable text component and an immutable, UI-independent cycle.
  Cadence and animation tokens remain in `Theme.Motion`. No per-row timers/tasks.

## Decisions and acceptance

- Mac only: five-second readable holds, half-second row staggering, brief flips.
  Reuse the popover's existing clock publisher at the stagger interval; reset on
  appearance or schedule change and stop publishing view state while hidden.
- Upcoming timing uses the full available detail line rather than competing with
  a trailing badge inside the 300pt popover. Other statuses retain dates and badges.
- Localized date order and 12/24-hour conventions come from Foundation. No new
  translatable phrases or languages are introduced.
- Reduce Motion shows both values statically. Accessibility exposes both values
  independently of the visual face; no changing countdown-only accessible label.
- Keep iPhone/widget rendering unchanged at the five inventoried call sites.
- Verify cycle boundaries and both sweep directions without real-time waits;
  verify full-date locale/time-zone behaviour; run canonical core and Mac checks
  serially with one worker, inspect rendered Mac layout, and obtain independent UI
  and spoiler-safety reviews before landing.

## Evidence and remaining work

Implemented in the canonical row detail slot. Upcoming Mac sessions now flip
between a live countdown and a full local date/time, without changing the other
four inventoried source call sites. Status badges remain visible for active,
finish-unconfirmed and finished sessions. Reopening the popover resets its cycle.

- `scripts/verify-core-tests.sh`: PASS, 167 tests, zero failures; the wrapper uses
  one worker. Five new cycle tests cover readable holds, top-to-bottom sweeps in
  both directions, six-row and single-row schedules, missed ticks and clock
  correction. Three date tests cover full months, 12/24-hour conventions, and
  local day rollover at a non-hour UTC offset.
- `scripts/verify-mac-build.sh -jobs 1`: PASS, arm64 and x86_64.
- `scripts/verify-ios-build.sh -jobs 1`: PASS, including Widget extension; this
  verifies the shared row's generic-detail change reaches its existing callers.
  All build/test commands ran serially after checking for other active runs.
- Native visual QA used production shared rows, formatter, cycle and flip view
  at 300pt width. Inspected countdown, date and partial-sweep states; light,
  dark and December palettes; long German and Arabic formatted dates. Captured
  a running native animation. The user observed the preview and accepted it.
- Independent `ui-change-reviewer` and `spoiler-safety-reviewer`: no substantive
  findings, including existing-mechanism and existing-pattern checks. The UI
  reviewer also reviewed the final appearance-reset adjustment after compilation.
- `git diff --check`: PASS. WebStorm could not inspect the ignored worktree path;
  Swift/Xcode compilation supplied language checks instead.
- No added/changed translation IDs or languages: only Foundation-formatted dates
  were added through the existing string owner. No schema/storage/logging changes.

Reduce Motion and VoiceOver paths were inspected and independently reviewed;
system-setting toggles and screen-reader interaction were not exercised. Ordinary
date snapshots are visual format checks, not reviewed app translations. The core
build still reports the pre-existing Swift 6 isolation warning in
`SessionEndConfirmer.storageKey`; this change does not touch it.

Implementation is verified and reviewed; land and push, then remove this completed
task in the required follow-up commit. Temporary evidence is retained under the
root `tmp/mac-board-evidence/` before removing the isolated worktree.

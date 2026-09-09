# Task 30: session boundary changes may not reach every surface

**Status: OPEN, narrowed 2026-09-09. The one known instance is fixed; what is left is the audit
that finds out whether there are others.**

## The issue

Session start and effective-end decisions are shared, but the app, Home Screen widgets, alerts and
Live Activities each wake or refresh through a different platform mechanism. A boundary changing
while one of those surfaces is inactive may therefore leave that surface showing an older state
than the others.

The shared rules are not the risk — `SessionResolver`, `ScheduleBoundary` and
`RaceWeekendResolver` are one implementation and every surface uses them. The risk is entirely in
the *delivery*: who gets told, by what mechanism, when a boundary moves.

## Fixed, 2026-09-09: a confirmed end never reached WidgetKit

Raised as this task's known example on 2026-09-05, and it was real. `SessionEndConfirmer` polls
OpenF1 for an authoritative end and fires `onChange` when it finds one; `ScheduleStore` forwarded
that to `objectWillChange` and nothing else. So a session OpenF1 said had ended re-rendered the
open app's views and left the Home Screen widget holding a timeline built from the grace-window
estimate — still saying *In Progress*, until its next entry. For a race the grace period is 90
minutes, which is the whole of the window this feature exists to shorten.

`performRefresh`'s reload could never have covered it: that one fires when the fetched *weekends*
differ, and a confirmed end changes none of them.

The callback now reloads timelines as well. Both reload sites log a `reason`, because
"widget reload requested" from two causes is a log a reader cannot use. The gap had been written
down on `SessionEndConfirmer.onChange` since 2026-09-05 as "separate task if it is ever seen to
matter"; that comment is now the contract instead — anything else caching a boundary belongs in
that callback rather than in a second mechanism beside it.

- [x] `scripts/verify-core-tests.sh` — 118 tests, 0 failures, 2026-09-09. This is the run that
      matters for compilation: `ScheduleStore.swift` is the only source changed and the package
      compiled it, for macOS.
- [ ] `verify-widget-build.sh`, `verify-ios-build.sh`, `verify-mac-build.sh` — **could not run
      2026-09-09**, and the blocker is the environment rather than the code: `xcodebuild` resolves
      package dependencies through `sandbox-exec`, which inside an agent sandbox fails at
      `sandbox_apply: Operation not permitted` before any compilation starts. All three fail
      identically and would fail on an unmodified checkout. Run them from a normal shell.
- [ ] **Not observed on a device, and there is no test that could stand in.**
      `reloadAllTimelines` is a WidgetKit call with no seam, which is exactly why the neighbouring
      `ScheduleChangeDetectionTests` test the *decision* to reload rather than the call. What is
      unproven is the whole point of the change: that the Home Screen widget leaves *In Progress*
      when OpenF1 confirms an end. It wants a session in its grace window with the app open.

## What is left

The audit the general issue asks for, which the one fix above does not answer. For each surface —
app views, Home Screen widget, alerts, Live Activity — and each way a boundary can move — a
schedule fetch, a confirmed end, the passage of time — does the surface find out?

Measured 2026-09-09 while fixing the widget, and more definite than "unknown". **The same root
cause reaches two more surfaces**, because both are woken by the same three moments and a
confirmed end is none of them:

- **Alerts.** `SessionAlerts.reschedule` is called from `.task`, `.onChange(of: store.weekends)`
  and on an authorization change — `ContentView.swift:129,136,144` and
  `NoSpoilersMacApp.swift:164,182`. A confirmed end changes `store.weekends` not at all, so none
  of them fire. The safe-to-watch alert therefore stays pending at the grace-window estimate.
  **This may be acceptable as designed**: `reschedule` is deliberately wholesale, and its own
  comment names "each launch and activation" as the thing that makes a wrongly-timed alert
  self-correcting. What the comment does not say is that the alert can fire, at the wrong time,
  before the next activation arrives — and the safe-to-watch alert is precisely the one the
  confirmer exists to make earlier. Deciding that is the audit's job, not a defect to fix on
  sight.
- **The Live Activity.** `SessionActivityController.refresh` is called from exactly the same
  moments (`ContentView.swift:134,137`), so it has the same gap, plus the case the controller
  cannot see at all: a confirmed end arriving while the phone is locked. The extension's own
  staleness re-render is the other half of that, and has never been observed on hardware — see
  `docs/guides/testing.md`.
- **The widget, for the other two boundary sources.** A schedule fetch is covered
  (`performRefresh`) and a confirmed end now is. The passage of time is the third case and rests
  entirely on the timeline's own entries; nothing has checked it.

Neither of the first two is a one-line fix in the shape of the widget's. `ScheduleStore` lives in
Core and cannot reach `alerts` or `activities`, which the app layer owns — so the wiring is a
design decision about who observes `confirmedEndDates`, which is why it is the audit rather than
an afterthought to it.

Each is a read of the wake path, not a change. A defect found here is likely one line in the same
shape as the fix above, and belongs in whichever callback already exists rather than in a new
mechanism.

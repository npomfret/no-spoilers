# Task 23: Answer 4.2.2 with functionality, not prose

**Status: OPEN. Started 2026-08-22.**

## Why

iOS `1.1.2` (build 31) was rejected on 2026-08-21 under **4.2.2 Minimum Functionality**, reviewed on
an iPad Air 11-inch (M3). It is the fourth time 4.2.2 has been cited and the first time it has been
cited *alone* — the 4.1(a) Copycats reason that accompanied every previous rejection is gone, so the
wordmark removal and metadata sweep of 2026-08-13 worked. See `tasks/16-ios-app-review-acceptance.md`
for that history.

Apple's message was boilerplate and engaged with nothing in the detailed 2026-08-13 reply. Task 16's
open decision 2 was "screenshots alone may be enough, or it may need a Live Activity /
notifications. Cheapest first." **The cheapest thing has now been tried and did not work.**

So this task takes the other branch: add functionality that a web page structurally cannot have.
That is the literal text of the accusation — "does not sufficiently differ from a web browsing
experience" — and it is answerable in code rather than in argument.

## Constraints

- **The spoiler guarantee is not negotiable for this.** `.claude/rules/spoiler-safety.md` applies in
  full. Nothing added here may introduce a result, standing, position, or result-shaped field to any
  model, store, fixture, log or string.
- A **quiz was considered and rejected** on 2026-08-22. Two reasons, both fatal: a question bank of
  historical results is exactly the result-shaped storage the guarantee forbids, and it would
  falsify the sentence "there are no result fields anywhere in the app's data model" which is both
  the best 4.2.2 argument and the 4.1 defence — a sentence already sent to Apple in writing. Second,
  "after the last event has finished" is not a safe window for a replay watcher, who is the entire
  user. A quiz is the one screen in this app that cannot be glanced at safely.
- **Notification copy is pushed content the user cannot decline to read.** Wording is a
  spoiler-safety surface in its own right and needs an audit before it ships. A finish alert
  arriving late implies an overrun; that is the specific case to think about.

## Approved patterns this builds on

- `TimelinePlanner` — pure, `now` passed in, no clock inside, `horizon`/`maxEntries` owned by the
  caller that has to live with the platform limit. This is the model for anything that plans future
  moments, and the notification planner follows it exactly.
- `SessionResolver.status(for:at:nextSession:confirmedEndAt:)` and
  `SessionResolver.effectiveEndDate(for:nextSession:confirmedEndAt:)` — the only definitions of
  when a session starts and is over. Nothing here may compute either independently.
- `SessionEndConfirmer` — already knows real end times from OpenF1 and already persists them to the
  App Group. The hard part of "is it *actually* finished" is built.
- `Strings.swift` per target; `Theme` for anything visual.

## Plan

### Phase A — one enumeration of schedule boundaries — **IN PROGRESS**

`TimelinePlanner.boundaryDates` already computes *every moment at which what the product should be
showing changes*: session starts, session effective ends, and the 24h recently-finished window of a
weekend expiring. Notifications need the same traversal, but they need to know **which session and
which kind of event**, where the widget only needs the bare date.

Writing that traversal a second time would put two answers to "when does this session end" in the
package, which is the drift the core rules call a correctness issue. So the traversal moves to
`ScheduleBoundaries` and returns `[ScheduleBoundary]`; `TimelinePlanner` keeps its behaviour exactly
and maps to dates. Its tests are the proof that nothing moved.

### Phase B — plan the alerts (Core, pure, testable)

A planner in the shape of `TimelinePlanner`: schedule + confirmed ends + preferences + `now` in,
an ordered list of alerts out. iOS allows **64 pending local notifications**, so the cap is a
parameter the caller owns, exactly as `maxEntries` is.

### Phase C — deliver them (iOS target)

`UNUserNotificationCenter`: permission, scheduling, replacing the pending set. Local notifications
need no entitlement — `NoSpoilersApp.entitlements` holds only the App Group and does not change.
Rescheduled on launch and on `scenePhase == .active`, which is the same trigger the widget install
check already uses.

### Phase D — preferences UI

The About sheet gained a caller-built `extra` slot in `a8a356f`, and it is where the widget
instructions now live. It is the app's only menu and is where these belong too.

### Phase E — App Intents / Shortcuts / Siri

Separate and self-contained. "When's the next session?" in Siri and Spotlight, plus automation
support. The build currently extracts no App Intents symbols at all.

## Verification

- `scripts/verify-core-tests.sh` for A and B — both are pure and belong in the package's tests.
- `scripts/verify-ios-build.sh` for C, D and E.
- `spoiler-safety-reviewer` on the alert copy before any of it ships.

## Open risks

- Notification permission is a one-shot prompt. Asking on first launch, before the user knows what
  the app is for, is the reliable way to get it denied forever.
- 64 pending is a hard OS cap. A full season is well over that, so the cap has to be a deliberate
  window rather than an accident.
- None of this is guaranteed to move Apple. It is the branch that is left, not a certainty.

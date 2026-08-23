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

### Phase A — one enumeration of schedule boundaries — **DONE 2026-08-22** (`df57c7c`)

`TimelinePlanner.boundaryDates` already computes *every moment at which what the product should be
showing changes*: session starts, session effective ends, and the 24h recently-finished window of a
weekend expiring. Notifications need the same traversal, but they need to know **which session and
which kind of event**, where the widget only needs the bare date.

Writing that traversal a second time would put two answers to "when does this session end" in the
package, which is the drift the core rules call a correctness issue. So the traversal moves to
`ScheduleBoundaries` and returns `[ScheduleBoundary]`; `TimelinePlanner` keeps its behaviour exactly
and maps to dates. Its tests are the proof that nothing moved.

### Phase B — plan the alerts (Core, pure, testable) — **DONE 2026-08-22** (`df57c7c`)

A planner in the shape of `TimelinePlanner`: schedule + confirmed ends + preferences + `now` in,
an ordered list of alerts out. iOS allows **64 pending local notifications**, so the cap is a
parameter the caller owns, exactly as `maxEntries` is.

### Phase C — deliver them (iOS target) — **DONE 2026-08-22**

`UNUserNotificationCenter`: permission, scheduling, replacing the pending set. Local notifications
need no entitlement — `NoSpoilersApp.entitlements` holds only the App Group and does not change.
Rescheduled on launch and on `scenePhase == .active`, which is the same trigger the widget install
check already uses.

### Phase D — preferences UI — **DONE 2026-08-22**, regrouped 2026-08-23

The About sheet gained a caller-built `extra` slot in `a8a356f`, and it is where the widget
instructions now live. It is the app's only menu and is where these belong too.

**Seven per-session switches became three groups on 2026-08-23** — free practice, qualifying,
races. Seven was one row per `SessionKind`, which is the schedule's vocabulary and not the
reader's: nobody wants Practice 2 and not Practice 3.

The preference is now *stored* as groups, not merely displayed as them. A per-kind store behind a
grouped UI has states the UI cannot draw, and the first half-selected group would have to be
rendered as something, silently. `SessionAlertPlanner` still takes `Set<SessionKind>` and does not
know `SessionAlertGroup` exists — planning is per session, grouping is a preference, and the
expansion happens once in `SessionAlertDefaults.current()`.

`SessionKind.alertGroup` is the written direction and `SessionAlertGroup.kinds` is derived from it,
so the two cannot disagree and a new session kind fails to compile until it is given a group.
Two of the three names are not guessable — the Sprint is under Races, Sprint Qualifying is under
Qualifying — so each row prints the sessions it covers underneath.

The old `alerts.kinds` key is not migrated. The alerts had been with four internal testers for one
day; there was no preference out there worth carrying, and a migration nobody exercises outlives
the thing it was written for. The cost of the change is that "the Grand Prix but not the Sprint" is
no longer expressible.

### Phase E — a Live Activity for the next session (ActivityKit)

Added to the backlog 2026-08-22, and **ranked above App Intents** for this task's purpose. Prompted
by the BBC Sport app starting one unprompted for a football match — that is push-to-start
(iOS 17.2+), which needs a server; ours does not, and the difference is instructive.

**Why this is the strongest answer to 4.2.2 we have.** The accusation is "does not sufficiently
differ from a web browsing experience". A Live Activity is on the Lock Screen seconds after the app
is opened, and a web page structurally cannot put anything there. It is also *reviewable*: it can be
named in the review notes and screenshotted, where App Intents only helps if the reviewer thinks to
try Siri. Every previous 4.2.2 answer has been prose; this one is visible.

**It needs no backend and no permission.** `Text(timerInterval:)` counts down on its own from a date
range handed over once, so there is no APNs, no server and no push-to-start. Live Activities need no
authorization prompt at all — worth noting beside the notification prompt that turned out never to
have been shown to anybody (below).

**The pieces already exist.** `NoSpoilersWidgetBundle` can host an `ActivityConfiguration` in the
same extension, so there is no new target. `ScheduleBoundaries.all()` already produces
`sessionStart` and `sessionEnd` for the next session — its own doc comment anticipates exactly this
caller: *"anything that speaks to the user — a notification, an intent's answer — has to know which
session moved and which way."* This is the third caller that type was built for, and it must not
compute either instant independently.

Sketch, to be confirmed against the repo before implementing:

- `SessionCountdownAttributes` in `NoSpoilersCore`, shared by the app and the extension.
- An `ActivityConfiguration` added to `NoSpoilersWidgetBundle`, beside `NoSpoilersWidget`.
- Content is a Grand Prix name, a session name and a clock. Nothing else, ever — the same three
  fields the widget already draws.
- Started from the foreground when the next boundary is within range; ended at the session's
  effective end.

**The constraint that shapes the whole feature: 8 hours.** A Live Activity runs 8 hours active and
stays visible up to 4 more in a stale state. A race weekend is three days, so this cannot be "start
it on Friday and watch it all weekend" — it is one activity for the *next* session, started when the
app is opened. That is a useful shape but not the one people will assume, so it must not be
described as weekend-long in any copy or listing text.

Second constraint, following from having no server: an activity can only be *started* while the app
is in the foreground. The UX is therefore "open the app, and the countdown moves to your Lock
Screen", which is close to how the app is already used.

**Spoiler surface.** Small but real: this is pushed content on a locked screen that the user cannot
decline to read, same class as the notification copy. It shows a clock, but it needs
`spoiler-safety-reviewer` like anything else that speaks.

**Sequencing.** Not to be started before the alert copy has had its audit, the permission fix has
been observed working end to end, and Apple has had its Resolution Center reply. Stacking a second
user-facing surface on top of a feature that was silently inert for every user is how two features
end up looking fine and not being fine.

### Phase F — App Intents / Shortcuts / Siri

Separate and self-contained. "When's the next session?" in Siri and Spotlight, plus automation
support. The build currently extracts no App Intents symbols at all. Kept because it is cheap once
the domain is this well factored, but Phase E answers the rejection more directly.

## Verification

- `scripts/verify-core-tests.sh` for A and B — both are pure and belong in the package's tests.
- `scripts/verify-ios-build.sh` for C, D and E.
- `spoiler-safety-reviewer` on the alert copy before any of it ships.

## Open risks

- Notification permission is a one-shot prompt. Asking on first launch, before the user knows what
  the app is for, is the reliable way to get it denied forever. **Resolved:** it is requested only
  from `SessionAlertsView`, the first time someone switches an alert on. Nothing in app startup can
  reach it.
- 64 pending is a hard OS cap. A full season is well over that, so the cap has to be a deliberate
  window rather than an accident. **Resolved:** `SessionAlertPlanner` takes the cap and returns the
  soonest N, so the OS never chooses which to drop.
- None of this is guaranteed to move Apple. It is the branch that is left, not a certainty.

## Verifying it on a simulator — `scripts/alerts_check.py`

Added 2026-08-22. Launches the app on `NoSpoilers-iPhone`, then streams the `alerts` log channel
back and reports the counts. `--push` delivers one notification carrying the exact strings
`Strings.Alerts` produces — extracted from the Swift rather than transcribed, so the sample cannot
drift from the product and still screenshot convincingly.

First run found two things:

- **The app reached the scheduler and correctly declined** — `not scheduling authorization=0`. The
  whole path from launch to `UNUserNotificationCenter` works. It was read at the time as "the only
  missing step is a human pressing Allow". **That reading was wrong, and the correction is below.**
- **A foreground notification was being dropped silently.** No `UNUserNotificationCenterDelegate`
  was set, so iOS swallowed anything arriving while the app was open. That is the wrong answer for
  both alerts: a start warning is most likely to land while someone is in this very app checking
  that session's time, and a safe-to-watch alert arriving while the app is open is exactly when
  someone is deciding what to put on. Fixed with `willPresent` returning `[.banner, .sound]`.

`--push` is also gated on authorization: `simctl` accepts the payload and iOS displays it nowhere.
Both screenshots taken before the prompt was answered showed an empty screen.

## The prompt had never been shown to anyone — 2026-08-22

`authorization=0` is `UNAuthorizationStatusNotDetermined`: not "the user said no", not "the user has
not got round to it", but **nobody has ever been asked**. Three defects, each of which hid the next.

- **`SessionAlertsView` asked from `.onChange(of: wantsAnything)`, and both alerts ship on.** So
  `wantsAnything` is already `true` when the screen first draws and never changes. Anyone leaving
  the defaults alone — everyone — got no prompt for the life of the install, every reschedule logged
  `not scheduling`, and the screen looked entirely correct while doing it: two switches on, no
  warning, no alerts. Opening the screen with an alert on now asks.
- **Nothing rescheduled when permission arrived.** The grant happens under the About sheet, and
  dismissing a sheet is not a scene change, so even a granted permission bought nothing until the
  app was next backgrounded and reopened. `ContentView` now reschedules on `alerts.authorization`,
  beside the weekends and scene-phase triggers it already owns.
- **`alerts_check.py` could not observe the launch it was checking.** It launched the app and *then*
  attached the log stream, missing a line written milliseconds into launch — and `simctl launch` on
  an already-running app returns the existing pid without re-running anything, so once the app was
  up it saw an empty channel and blamed the missing prompt. It now terminates, waits for the
  stream's banner to confirm it is attached, then launches.

The lesson worth keeping: **a default-on preference cannot be the trigger for a one-shot prompt**,
because the change it waits for has already happened.

## An alert has now fired — 2026-08-23

**Observed on a real device**, on build `10003`, for the Dutch Grand Prix start. It was reported as
missing first and then found: it had arrived and been scrolled past. That closes the last unproven
step of Phases A to D — the plan reaches the OS, the OS holds it, and it is delivered to a phone.
The route that got there was a real session an hour out, not a harness.

Worth keeping from the false alarm: **the alert arrived and was not noticed.** A start warning
competes with everything else on a lock screen, and "I got no notification" and "I did not see the
notification" are the same report. Anything that measures whether alerts work has to account for
that before treating a user's account as evidence.

## Still open after C and D

- **The safe-to-watch alert has not been observed**, and its timing is the interesting half.
  `effectiveEndDate` is `confirmedEndAt ?? (endsAt + gracePeriod)`, and a race's grace is 90
  minutes on top of a two-hour default duration — so the estimate fires 3½ hours after lights out
  unless OpenF1 confirms the real end first and the app is opened to rebuild the pending set.
  **Opening the app after a confirmed end has passed drops the alert rather than firing it**:
  `plan` walks boundaries after `now`, so a confirmed end in the past produces none, and
  `reschedule` has already cleared the pending set. Defensible — by then the session reads as
  finished on the screen in front of you — but it means the all-clear is not guaranteed, and
  nothing says so anywhere else.
- The alert copy has not been through `spoiler-safety-reviewer`.
- Phase E — a Live Activity for the next session — backlogged 2026-08-22, not started.
- Phase F — App Intents / Shortcuts / Siri — not started.
- **Xcode Cloud has no compute quota left**, confirmed 2026-08-22: runs 33, 34 and 35 were all
  cancelled 5–8 seconds after creation with `startedDate: None` and no `cancelReason`, and
  `POST /v1/ciBuildRuns` answers `500`. Until it resets, every build is a local `scripts/ship-ios.sh`
  run. `1.1.2 build 10003` went out that way and is with the internal testers.

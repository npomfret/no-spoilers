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

### Phase E — a Live Activity for the next session (ActivityKit) — **DONE 2026-08-25**

Added to the backlog 2026-08-22, and **ranked above App Intents** for this task's purpose. Prompted
by the BBC Sport app starting one unprompted for a football match — that is push-to-start
(iOS 17.2+), which needs a server; ours does not, and the difference is instructive.

**Why this is the strongest answer to 4.2.2 we have.** The accusation is "does not sufficiently
differ from a web browsing experience". A Live Activity is on the Lock Screen seconds after the app
is opened, and a web page structurally cannot put anything there. It is also *reviewable*: it can be
named in the review notes and screenshotted, where App Intents only helps if the reviewer thinks to
try Siri. Every previous 4.2.2 answer has been prose; this one is visible.

**It needs no backend. It does need permission — see the correction at the end of this file.**
`Text(timerInterval:)` counts down on its own from a date range handed over once, so there is no
APNs, no server and no push-to-start. ~~Live Activities need no authorization prompt at all — worth
noting beside the notification prompt that turned out never to have been shown to anybody
(below).~~ **Wrong, corrected 2026-08-25.** There is a prompt, iOS raises it on the first activity,
and the irony of writing that sentence beside the notification-prompt defect is not lost.

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

**Overtaken 2026-08-25**, deliberately: Nick chose one submission carrying everything rather than a
release per phase. The reasoning above does not disappear with the sequence — it becomes the list of
things to *check* before this ships rather than before it is written. The alert copy audit is done
(below); the permission fix has been observed end to end and both alerts have fired on a real
device; the Resolution Center reply is still Nick's to send. What is genuinely not discharged is
that **nothing has looked at a Live Activity or heard a Siri answer on a device** — see the
verification note at the end of this section.

#### What building it actually cost — 2026-08-25

Close to the sketch, with three corrections worth keeping.

- **`Text(timerInterval:)` was the wrong idiom and is not used.** The sketch assumed a self-running
  countdown, and there is one — but a Live Activity **does not re-render with the clock**. The
  system redraws it when the app pushes an update, and with no server the app cannot push one from
  the background. So an activity that says "starts in" is still saying it a minute after the session
  began. `staleDate` is the honest answer: it is set to the moment the content stops being true —
  the start when upcoming, the effective end when live — and the system dims a stale activity rather
  than letting it read as a live claim. The countdown itself is `Text(_:style: .relative)`, which is
  the idiom the widget already uses.
- **A running session gets no countdown at all.** The live phase says `Strings.Schedule.inProgress`
  and stops. Counting down to a running session's end would be counting to the grace-window
  *estimate* — the same guess `SessionAlertPlanner` places the safe-to-watch alert on, half an hour
  behind the fact — and a clock ticking toward zero reads as "nearly over", which is a claim about
  the session this product has no business making.
- **`SessionActivityPlanner` was renamed `FeaturedSessionPlanner` before it shipped**, because
  Phase F wants exactly the same sentence and a boundary named for one of its two callers is a
  boundary the other one will eventually be copied instead of reusing. It answers "what is on, or on
  next" — the session running, or the next to start. `lookAhead` stays caller-owned and the two
  callers genuinely differ: 8 hours for the activity, `.infinity` for the intent.

Nine tests in `FeaturedSessionPlannerTests`, including the back-to-back clamp and the grace window,
so the decision to start one is assertable even though the activity itself is not.

The type lives in Core under `#if os(iOS)`: ActivityKit matches a running activity to its
configuration by attribute-type identity, so the app and the extension must share one declaration —
a copy in each compiles and then never renders. The app target gained
`INFOPLIST_KEY_NSSupportsLiveActivities`; `NoSpoilersApp.entitlements` did not change, as predicted.

### Phase F — App Intents / Shortcuts / Siri — **DONE 2026-08-25**

Separate and self-contained. "When's the next session?" in Siri and Spotlight, plus automation
support. Kept because it is cheap once the domain is this well factored, but Phase E answers the
rejection more directly.

**It reuses both of Phase E's boundaries and adds no domain logic.** `FeaturedSessionPlanner` gives
the answer, so the sentence Siri speaks and the countdown on the Lock Screen cannot disagree.
`ScheduleSnapshotLoader` gives it the schedule — which meant **moving `resolveWidgetData` out of
`NoSpoilersWidget.swift` into Core**, where it is now `ScheduleSnapshotLoader.load()`. It was
private to the widget for as long as the widget was the only process that wakes up cold with nothing
in memory; an intent launched by Siri is the second, with the same problem and the same right
answer, and a copy beside the original would have been two answers to where the schedule comes from.
52 lines left the widget and none of its behaviour changed.

**The one rule this feature cannot follow is the strings rule**, and it is the framework's doing.
`appintentsmetadataprocessor` extracts the intent title, its description, the shortcut's short title
and the spoken phrases at *build* time, and fails the build on anything that is not a literal at the
declaration site — `expect a compile-time constant literal`, then `'LocalizedStringResource' must be
initialized with a call to its initializer or a string literal`. Those four are inline in
`NextSessionIntent.swift` under a comment saying so, and `Strings.Intents` carries a note pointing at
them. What the intent says at *run* time is not extracted and lives in `Strings.Intents` normally.
`systemImageName` is the same constraint, so `Theme.Icon.sessionCountdown` is written out as
`"timer"` there with the token named in a comment.

**`AppShortcutsProvider` is the half that matters for review.** Without it the intent is reachable
only by someone who opens the Shortcuts app and goes looking, which is nobody — and a reviewer
checking what this app does that a browser cannot would never find it.

**Verified by reading the extracted metadata, not by trusting the build.** "Extracted no relevant App
Intents symbols, skipping writing output" is what the build log said before this and it is not an
error, so a green build proves nothing here. `Metadata.appintents/extract.actionsdata` inside the
built `.app` now carries `NextSessionIntent` with `isDiscoverable: true`, and an `autoShortcuts`
entry with all three phrase templates and `${applicationName}` substitution in place.

## Verification

- `scripts/verify-core-tests.sh` for A, B and E's planner — all pure and belonging in the package's
  tests.
- `scripts/verify-ios-build.sh` for C, D, E and F.
- `spoiler-safety-reviewer` on the alert copy before any of it ships.

**All five wrappers pass as of 2026-08-25** — `verify-core-tests` (98 tests, up from 88),
`verify-mac-build`, `verify-widget-build`, `verify-ios-build`, `verify-python-selftests`.

**That was compile confidence, and for Phase F metadata confidence. It was not behaviour.** What has
since been observed, and what has not:

- **Siri answers, on real hardware — 2026-08-25**, on TestFlight build `10008`. Asked "what is on
  next in No Spoilers" and it named the Italian Grand Prix. That is the whole of Phase F proven end
  to end: the metadata reached the device, `AppShortcutsProvider` made it findable, the intent ran
  in a process the system started, `ScheduleSnapshotLoader` found a schedule, and
  `FeaturedSessionPlanner` picked the right session. It is also the first thing in this task ever
  confirmed anywhere other than a build log.
- **The Live Activity is proven on the simulator only** — see "The prompt nobody knew about" below.
  It starts, it updates, it ends a superseded one, and both the Dynamic Island and the Lock Screen
  presentations render. Not on hardware, and it cannot be until a session is within eight hours,
  which is 4 September at the earliest.
- **A Lock Screen widget renders on real hardware — 2026-08-26**, on build `10008`, placed by hand
  through Lock Screen customisation because they cannot be placed programmatically (Phase H
  follow-on). That closes Phase H, which had compile confidence and nothing else since 2026-08-24,
  and it settles the question the accessory families actually raised: they render in `.accessory`
  vibrancy, which flattens every colour into one material, so the decision to say "in progress" in
  words rather than in `stateLive` red was load-bearing rather than cautious. *(Which of the two
  families was placed was not recorded at the time; the rectangular tile is the one the review
  notes lead with.)*

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

## Phase G — the same alerts on macOS — **DONE 2026-08-23**

Raised by a tester who was asked for notification permission when installing the Mac app and
assumed it was ours. It was not: the Mac binary did not link `UserNotifications` at all, which
`otool -L` on the release archive settled in one line. But the question underneath was right — the
menu bar app sits on a desktop all day, and a start warning there competes with less than one on a
phone does. Today's alert arrived and was scrolled past.

**`SessionAlertDefaults` and `SessionAlertScheduler` moved to Core** rather than being copied. A
second scheduler beside the first would have been two spellings of every preference key and two
places to fix the next permission defect. The alert copy moved with them, because it ships to two
apps and is the one string a user cannot decline to read.

**`SessionAlertSettingsRows` is shared and the screens are not.** The iOS sheet and the macOS
settings pane look nothing alike, but the rule about when to spend the one-shot permission prompt
is the same rule, and it took three defects to get right. Each platform passes in its own route to
system settings; `Strings.Alerts` names the pane per platform with `#if os(macOS)`, as `AboutView`
already does.

Rescheduling on macOS hangs off `store.$weekends` rather than a lifecycle hook: the cache load in
`ScheduleStore.init` publishes before the delegate finishes launching and every refresh publishes
again, so one subscription covers the cold launch, the hourly timer and the fetch a popover
triggers — the three moments iOS covers with `.task`, `scenePhase` and an `onChange`.

**Two things only running it could have found.**

- **`.removeDuplicates()` on `$authorization` is load-bearing.** `reschedule` begins by calling
  `refreshAuthorization`, which *assigns* `authorization`, and `@Published` fires on assignment
  rather than on change — so the sink fed itself several hundred times a second. The first signed
  build wrote 7MB of `not scheduling` before anyone read the log. iOS never had this because
  SwiftUI's `onChange` is change-based. After the fix: three lines per launch.
- **A Debug build from DerivedData never finishes launching** — no status item, no `ScheduleStore`
  log line, no crash. Stashing the change reproduced it exactly, so it is the build, not the code.
  Anything checking macOS behaviour has to run a signed archive.

## Phase H — Lock Screen widgets, and the iPad size that was switched off — **DONE 2026-08-24**

Sequenced ahead of Phase E, and the survey that found it started from the same question: what can
this app put somewhere a web page structurally cannot reach? A Live Activity was the answer on
record. **A Lock Screen widget is a better one per unit of work**, and the reason is that it is
permanent — an activity runs 8 hours and then stops, where an accessory widget someone has placed
is still there next weekend.

Two changes, both in `NoSpoilersWidget.swift`, both to `supportedFamilies`:

- **`.accessoryRectangular` and `.accessoryInline` are new.** Rectangular is the Lock Screen and
  StandBy tile and draws the same three fields every other family leads with — the Grand Prix, the
  session, the clock. Inline is the single line beside the Lock Screen clock and gets the session
  and the clock, because both do not fit and someone who placed it knows which weekend it is.
  `.accessoryCircular` was **deliberately not added**: the idiomatic content for it is a `Gauge`
  showing progress toward the next session, progress needs a start instant, and this task's own
  constraint is that nothing may compute a session boundary independently of `SessionResolver`.
  A circle with a name and a countdown crammed into it is worse than no circle.

- **`.systemExtraLarge` is restored.** It was dropped in `f420206` on 2026-03-29 — one clause in a
  commit body about icons and the small-view redesign, with no reason given — a month before the
  first rejection. **`extraLargeView` was never deleted**, nor its `Theme.Canvas` mapping nor its
  preview, so it has been compiling and unreachable ever since. It is the iPad-only family, and
  every 4.2.2 rejection including 2026-08-21 was reviewed on an iPad.

Three things the accessory families forced, each of which would have been a defect if assumed:

- **They get no container background.** `NoSpoilersBackground` is the app's own dark surface; on
  the Lock Screen the system supplies the material. `NoSpoilersWidgetBackdrop` now branches on
  family so the app's background is named as belonging to the system families, rather than relying
  on three different placements — Lock Screen, StandBy, tinted Home Screen — to strip it.
- **They get no `Theme.Palette` and no `Theme.Canvas`.** Accessory families render in `.accessory`
  vibrancy mode, which flattens every colour into one material: `stateLive` red arrives as exactly
  the shade of the body text. So a live session says so in words here, where `smallSessionTime`
  says it in colour. `canvas` is not reached at all — `body` routes accessory families away before
  one is asked for, which keeps `Theme.Canvas` the single size axis rather than growing a case
  that resolves to nothing.
- **`offSeasonView` and `noDataView` do not fit.** Both are message cards — icon, title, paragraph.
  Both reduce to their existing title, so no new copy was written.

**No new user-facing strings.** That is deliberate: this is content pushed onto a locked screen
that the reader cannot decline to look at, the same class of surface as the alert copy, and the
right way to add a surface like that is to show fewer of the fields already audited rather than new
ones. The spoiler exposure is unchanged.

**Verification.** `verify-widget-build.sh`, `verify-ios-build.sh` and `verify-core-tests.sh` all
pass (88 tests). **That was compile confidence only until 2026-08-26**, when a Lock Screen widget was placed by hand on real hardware from build `10008` and rendered — see the verification note above. At the time of writing, nothing had looked at these families
rendered:

- Lock Screen widgets are placed through Lock Screen customisation, which `scripts/screenshots.py`
  does not drive — its `WIDGET_SIZES` is `("small", "medium", "large")` and it works by rewriting
  `gridSize` in the Home Screen plist, which accessory widgets do not live in.
- `.systemExtraLarge` cannot be placed on an iPhone at all, and this project owns no iPad
  simulator — `CLAUDE.md` names `NoSpoilers-iPhone` and nothing else.

So there are two follow-ons, and they are what stands between this and a screenshot for the
listing: teach `screenshots.py` the accessory families and `extraLarge`, and create a project-owned
`NoSpoilers-iPad`. Until then the previews in the file are the only look anyone has had, and a
preview is not a device.

### Phase H follow-on — the iPad half is done, the Lock Screen half cannot be done this way — 2026-08-24

**`.systemExtraLarge` is now verified rendering**, on a project-owned `NoSpoilers-iPad`
(`iPad-Pro-13-inch-M5-12GB`, iOS 26.5, 2064x2752 — the 13" listing slot). `WIDGET_SIZES` in
`scripts/screenshots.py` gained `extraLarge`; the camel-case spelling is SpringBoard's, established
by writing it and reading back what survived the boot rather than guessed. The capture shows the
two-column layout — full weekend on the left, NEXT UP on the right — against the seeded fixture.

**The Lock Screen families cannot be placed the way the Home Screen ones are, and the reason is
worth writing down so nobody spends the afternoon again.** The Home Screen works because
`IconState.plist` is SpringBoard's own declarative copy of the layout, which it reads on boot.
There is no such file for the Lock Screen. What was checked, in order:

- The poster store (`PRBPosterExtensionDataStore`) holds the selected Lock Screen poster and its
  appearance, but **no widget layout at all** — not in `posterAttributes`, not in the poster's
  `contents/`, `supplements/` or `renderingConfiguration`.
- Placement lives in chronod's `chrono.sql`, table `HostConfigs`, under host `::Complications`
  (`::SpringBoard-Homescreen` is the Home Screen's). Its `CHSWidgetConfiguration` archive carries
  `metricsByFamily` for families 10, 11 and 12 — sizes `{72,72}`, `{162,72}` and `{342,36}`, which
  are circular, rectangular and inline.
- A `CHSConfiguredWidgetContainerDescriptor` for family 11 was written into that archive and it
  **survived the boot** — read back intact, naming our extension. It rendered nothing, at every
  `location` value tried (0, 1, 2, 3).
- Read back later, chronod had **pruned the descriptor by itself**. That is the answer:
  `::Complications` is *derived* from state PosterBoard owns, and reconciliation drops anything not
  backed by a real Lock Screen configuration. Writing it can never work.

The only remaining route is driving the Lock Screen customisation UI, and that is **not** something
to automate here: it means synthetic clicks at absolute screen coordinates against the real
desktop, which on a shared machine hits whatever window is actually under the pointer. Do not add
it. If a Lock Screen screenshot is ever needed for the listing, add the widget by hand once on
`NoSpoilers-iPhone` — the configuration then persists on that device, and seed/reboot/lock/capture
is ordinary tooling from there. Locking itself is safe to script: the Simulator's
`Device ▸ Lock` menu item can be clicked **by name**, which is unambiguous.

**Two traps in `screenshots.py` were found by walking into both**, and both are now handled:

- `resolveWidgetData()` falls back to the network on a cache miss **and writes the result back**, so
  a device seeing the widget for the first time poisons its own cache with the live calendar before
  any fixture exists. The capture then shows today's races and looks entirely correct.
  `confirm_fixture_intact` now fails the run instead.
- The widget page was being missed entirely: installing parks SpringBoard on the page the new icon
  landed on, and it stayed there across two further reboots, producing a clean screenshot of
  Apple's apps. `set_widget_size` now leaves the widget's page as the **only** page.

  The trade is that iOS reflows the other apps onto that page, so listing screenshots show a
  populated Home Screen rather than a widget alone. **This was put to Nick on 2026-08-24 and the
  populated Home Screen was chosen** — a screenshot silently missing its own subject is the worse
  failure, and it had already happened three times in one afternoon. Leaving the widget alone is
  not a free choice: the apps need a second page to live on, and a second page is exactly what the
  device parks on. Do not quietly restore `state["iconLists"][0] = [...]` to make the picture
  emptier; that trades a decided question back for the flakiness.

**Known cosmetic debt.** `Text + Text` is deprecated from iOS 26 and the file now emits six such
warnings — four new, two pre-existing in `stateLabel`. The composition was kept in the established
local spelling rather than converting two sites and leaving the third; converting all three needs
new `LocalizedStringKey` format functions and is a separate change.

## Still open after C and D

## The safe-to-watch alert has now fired too — 2026-08-23

Reported by the same tester on the same race. Both halves of the feature are now observed on a real
device: the start warning and the all-clear.

**Which path delivered it is not known, and the two mean different things.** The Dutch race started
14:00 BST; `endsAt` is 16:00 and a race's `gracePeriod` is 90 minutes, so the estimate fires at
17:30 — an hour and a half after the flag. OpenF1 gives `date_end` as 15:00Z, which is 16:00 BST, so
a confirmed end would have fired on time. The alert arriving at all says it was one of those; only
the arrival time tells you which, and nobody wrote it down.

It matters because the answer decides what to do next:

- **If it fired at 17:30**, the confirmer bought nothing in the field and the shipped experience is
  "safe to watch" arriving 90 minutes late — for a feature whose entire audience is people waiting
  to press play, that is the wrong end of the trade.
- **If it fired at 16:00**, the confirmation reached the pending set in time and the grace window is
  only ever a fallback.

The structural problem stands either way: the confirmation can only narrow the window if the app is
foregrounded between the confirmation being published and the estimated end, and if it is
foregrounded *after* the confirmed end has passed the alert is dropped instead — see below. That is
a lot of conditions on the useful outcome. **Log the fire time**, and consider whether a race's
90-minute grace is defensible without one.

- ~~**The safe-to-watch alert has not been observed**~~, and its timing is the interesting half.
  `effectiveEndDate` is `confirmedEndAt ?? (endsAt + gracePeriod)`, and a race's grace is 90
  minutes on top of a two-hour default duration — so the estimate fires 3½ hours after lights out
  unless OpenF1 confirms the real end first and the app is opened to rebuild the pending set.
  **Opening the app after a confirmed end has passed drops the alert rather than firing it**:
  `plan` walks boundaries after `now`, so a confirmed end in the past produces none, and
  `reschedule` has already cleared the pending set. Defensible — by then the session reads as
  finished on the screen in front of you — but it means the all-clear is not guaranteed, and
  nothing says so anywhere else.
- ~~The alert copy has not been through `spoiler-safety-reviewer`.~~ **Audited 2026-08-25**, read
  against `.claude/rules/spoiler-safety.md` directly rather than by the agent — see the audit
  section below. Clean, with one inherent timing channel recorded and deliberately kept.
- ~~Phase E — a Live Activity for the next session~~ **DONE 2026-08-25.** Not yet seen on a device.
- ~~Phase F — App Intents / Shortcuts / Siri~~ **DONE 2026-08-25, and heard on a device the same day** on build `10008`: "what is on next in No Spoilers" named the Italian Grand Prix.
- **The safe-to-watch alert's fire time is now recorded.** `SessionAlertScheduler.logDelivered()`
  reads `deliveredNotifications` on every reschedule and writes each alert's id and arrival instant
  to the `alerts` channel. That is the only route to it — nothing wakes the app when a notification
  fires, `willPresent` needs the app already open and `didReceive` needs a tap — and it is best
  effort by construction, because an alert the user swiped away is gone. It answers the question
  left open on 2026-08-23: whether the confirmed end reached the pending set in time, or whether the
  all-clear arrived 90 minutes after the flag.
- **Xcode Cloud has no compute quota left**, confirmed 2026-08-22: runs 33, 34 and 35 were all
  cancelled 5–8 seconds after creation with `startedDate: None` and no `cancelReason`, and
  `POST /v1/ciBuildRuns` answers `500`. Until it resets, every build is a local `scripts/ship-ios.sh`
  run. `1.1.2 build 10003` went out that way and is with the internal testers.

## The copy audit — 2026-08-25

Every string the product puts in front of someone who did not choose to look, read against
`.claude/rules/spoiler-safety.md`. Three surfaces now qualify, where the task began with one: the
notification bodies, the Live Activity, and what Siri says out loud — which is the strictest of the
three, because it can be asked for in a room with other people in it.

**Done by reading rather than by `spoiler-safety-reviewer`**, which this session was not permitted to
spawn. The rule file is short and the surface is four sentences; it is not a substitute for the agent
on a data-ingestion change, and the next one should go through the agent properly.

**Nothing carries a result-shaped field.** Every string is built from three values and no others —
`RaceWeekend.grandPrixName`, `SessionKind.displayName`, and an instant. There is no fourth, and no
new one was added: the Live Activity shows the same three fields the accessory widget families show,
which are the same three every other family leads with.

**No owned terms.** Checked across every changed Swift file; the only occurrences of "Grand Prix"
are the ones already throughout the product, and nothing says "F1", "Formula 1" or "Formula One".

One wording change came out of it: the intent's upcoming answer was *"Race at the Belgian Grand Prix
starts Sun, 24 Aug, 14:00"*, which reads clipped when spoken. It now says **starts on**.

### The one real finding, and why it stays

**A late safe-to-watch alert leaks that the session overran.** `effectiveEndDate` is
`confirmedEndAt ?? (endsAt + gracePeriod)`, so a red flag or a long delay pushes OpenF1's confirmed
end later and the all-clear arrives later with it. Someone watching the clock can infer that
something happened. This is the case the Constraints section flagged on 2026-08-22 and it is real.

**It is kept, because the alternative is worse in the direction that matters.** Firing at a fixed
estimate regardless of the confirmed end would mean telling someone a session is safe to watch while
it is still running — which is not an inference about an incident but a live broadcast, and the
actual spoiler this product exists to prevent. A timing channel that reveals "it ran long" is the
cost of never being wrong about "it is over".

It is also not addressable in copy, which is what an audit of copy can reach. The words are a fact
about a clock; the channel is the clock. Recorded here so the next person does not rediscover it and
assume nobody thought about it.

### The Live Activity's stale window

Second-order, and worth naming beside the above. An activity started as `upcoming` keeps saying
"starts in" until the app is next opened, because nothing can update it from the background. The
`staleDate` is set to the session start so the system dims it, and the relative time it draws goes on
being accurate — it counts up once the instant passes. So the failure mode is a dimmed card saying
how long ago a session started, which is a schedule fact and not a spoiler. Named because "the Lock
Screen is showing something out of date" is the kind of report that arrives without a diagnosis.

## The prompt nobody knew about — 2026-08-25

**iOS asks "Allow Live Activities from No Spoilers?" the first time an app starts one**, as an
inline prompt on the Lock Screen under the activity itself, with Don't Allow and Allow. Seen on the
`NoSpoilers-iPhone` simulator, on the first Live Activity this project has ever put in front of
anybody. Phase E asserted three times, in three files, that no such prompt exists.

**It is the notification permission again, one feature later**, and the resemblance is close enough
to be uncomfortable:

- Something the user can refuse, once, with no way back from inside the app.
- After a refusal `areActivitiesEnabled` is false, `refresh` returns having done nothing, and the
  Lock Screen simply stays as it was.
- Every log line reads as normal, and the feature looks exactly like one that is working and has
  nothing to show yet — which, given the 8-hour look-ahead, is its ordinary state.

The difference is that there is nothing to *request*, and therefore no one-shot prompt to spend:
iOS raises it on the first activity and `ActivityAuthorizationInfo` can be consulted freely. So the
fix is not about when to ask. It is about admitting the answer.

**What was done.** `SessionActivityController` publishes `activitiesEnabled` — optimistic until the
first refresh, so a fresh install does not warn about a prompt nobody has seen, and assigned only
on change, which is the macOS `removeDuplicates` lesson. `SessionAlertsView` gained a Lock Screen
section: a line explaining the feature when it is on, and an off-notice in the same shape as
`SessionAlertSettingsRows.deniedNotice` when it is not. Not in the shared rows — those are also the
Mac app's, and macOS has no ActivityKit.

**And the review notes now say to tap Allow.** A reviewer who dismisses that prompt loses the
strongest 4.2.2 answer in the submission, permanently, and would have had nothing telling them so.

### What the simulator run proved, and what it did not

With `lookAhead` temporarily widened to 40 days and reverted afterwards, uncommitted:

- `Activity.request` succeeds and returns an id.
- The lifecycle works — started, updated, then a superseded activity ended and replaced when the
  network refresh produced a different weekend to the one the cold cache had.
- The Dynamic Island renders: glyph in the compact leading, relative countdown in the trailing.
- The Lock Screen presentation renders: Grand Prix, session name, countdown, nothing else.

Not proven: any of it on real hardware, and the expanded Dynamic Island regions, which need a long
press. The 8-hour look-ahead is covered by `FeaturedSessionPlannerTests` rather than by this.

**The simulator will not lock from `Device ▸ Lock` under AppleScript** — the click returns a valid
menu-item reference and the framebuffer stays on the Home Screen, across four attempts and a device
restart. A person pressing ⌘L is what produced the Lock Screen capture. Worth knowing before
anyone tries to automate a Lock Screen screenshot again; `tasks/23`'s Phase H follow-on already
says not to drive that UI with synthetic clicks, and this is a second reason.


# Task 21: app code review — swipe navigation, season rollover, and shared-logic drift

**Status:** FIXED 2026-08-14. All seven sections addressed across six commits, `1bd8d1f`..`a4f58cc`.
Two items remain open and are marked below: the swipe fix has not been confirmed by hand, and the
2026 feed carries a Grand Prix name this app cannot map to a country.
**Raised:** 2026-08-14, read-only review of the iOS app, the macOS popover, and `NoSpoilersCore`
**Trigger:** the user reported that left/right swipe between weekends in the iOS app "doesn't always work"

Findings are ordered by what should be fixed first. Each is independently actionable. Everything here
is **read from the code, not measured** — where a finding is a hypothesis rather than a fact, it says
so. Nothing in this file has been reproduced under instrumentation.

Two findings are large enough to deserve their own task files once someone commits to them —
[§2 season rollover](#2-the-apps-stop-working-on-1-january-2027) and
[§5 duplicated logic](#5-the-same-logic-implemented-three-and-four-times). They are recorded here so
the review stays in one piece.

---

## 1. Swipe between weekends is unreliable (the reported bug)

`NoSpoilers/NoSpoilers/ContentView.swift:44-54`

```swift
TabView(selection: $selectedWeekendIndex) {
    ForEach(sortedWeekends.indices, id: \.self) { index in
        ScrollView {
            weekendView(sortedWeekends[index]).padding(16)
        }
        .refreshable { await refresh() }          // (a)
        .tag(index)
    }
}
.tabViewStyle(.page(indexDisplayMode: .automatic))
.animation(.easeInOut, value: selectedWeekendIndex)   // (b)
```

**(a) `.refreshable` on every page — the primary suspect.** Pull-to-refresh installs a gesture on the
inner `ScrollView` that competes with the page view's horizontal pan. A drag with any downward
component can be claimed by refresh instead of paging. That matches the reported symptom precisely:
flat horizontal swipes work, slightly diagonal ones don't, and it is worst at the top of the scroll
view where refresh is armed — which is where the user starts, because the header card is at the top.

**(b) `.animation(_:value:)` on a paged `TabView`.** The drag already runs an interactive transition
managed for us; writing `selection` at the end of it triggers a *second*, implicit animation across
the whole subtree. Removing this modifier costs nothing — paging animates itself.

**Contributing: the whole view tree is invalidated once a second.**
`ContentView.swift:76` publishes a 1 Hz timer into `@State now` on the **root** view, so every
`ForEach` page rebuilds every second, mid-gesture included. `sortedWeekends`
(`ContentView.swift:104-106`) is a computed property, so the array is re-sorted on each of those
passes too. This is not obviously fatal on its own, but it is the reason the failure is intermittent
rather than deterministic, and it should be scoped down regardless.

### Fix

1. Take `.refreshable` off the per-page `ScrollView`. Refresh already happens on `.task`
   (`:67`), on `scenePhase == .active` (`:79`), and on the interval timer (`:396`) — see
   [§4](#4-three-refreshes-on-launch-and-no-reentrancy-guard), which wants that path tidied anyway.
   If pull-to-refresh is worth keeping, it has to live outside the paging container.
2. Delete `.animation(.easeInOut, value: selectedWeekendIndex)`.
3. Scope the 1 Hz tick to the views that actually display a countdown rather than the root.

### Verification

Gesture reliability cannot be proven by a build. Needs a hands-on pass on device or simulator:
swipe left and right from the top of the page, from mid-scroll, and diagonally, across at least ten
attempts each, before and after. `scripts/verify-ios-build.sh` covers compile only.

### What was done — `1bd8d1f`

All three, as written. The `.refreshable` and the `.animation` came off the pager; the skeleton and
unavailable views keep pull-to-refresh, because they sit outside it and are the case where a manual
retry actually matters.

The 1 Hz tick was scoped by frequency rather than by view. Nothing on this screen renders sub-minute
granularity, so the timer still polls every second but only writes `now` when the minute rolls over
— one invalidation a minute instead of sixty, with status transitions still landing within a second
of the boundary they belong to. Scoping it to leaf views instead would have meant a `TimelineView`
per countdown, which is a pattern this codebase does not otherwise use; the frequency change gets
the same 60x reduction without introducing one.

**Still open.** Gesture reliability has not been confirmed by hand. `scripts/verify-ios-build.sh`
passes, which is compile confidence only. The verification this needs is the one described above:
ten swipes each from the top, from mid-scroll, and diagonally.

---

## 2. The apps stop working on 1 January 2027

`NoSpoilersCore/Sources/NoSpoilersCore/ScheduleFetcher.swift:4`
`NoSpoilers/NoSpoilersWidget/NoSpoilersWidget.swift:102`

```swift
URL(string: "https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/2026.json")!
```

The season year is hardcoded, in **two** places, and derived nowhere. At the rollover every user on
every surface — iOS app, menu bar, widget — sees a fully-finished 2026 season, permanently, with no
error state and nothing to indicate anything is wrong. It degrades into exactly the off-season
rendering, which looks deliberate.

This is a shipped-and-ticking defect, not a future feature. It is listed second only because the
swipe bug is what the user is looking at today.

Whatever the fix is, the URL must end up in **one** place — the two copies are the same concern
duplicated, and they are already two chances to forget. See
[§5](#5-the-same-logic-implemented-three-and-four-times); the widget's copy exists only because it
also re-implements the fetch.

Worth deciding explicitly rather than assuming: whether to derive the year from the clock, follow the
feed's own index, or roll over on a date. Deriving from the clock alone moves to the new season on
1 January, which may be before the new calendar file exists.

### What was done — `8614934`

**Decided: follow the feed's own index.** `_db/f1/config.json` publishes `calendarOutputYear`, which
is 2026 today. `ScheduleFetcher` reads it and then fetches `{year}.json`.

That beats the alternatives on the point that matters — who updates it. Deriving the year from the
clock rolls over on 1 January whether or not the new calendar file exists; a hardcoded rollover date
is a second thing to maintain and be wrong about. `calendarOutputYear` is maintained by the people
who publish the calendar files, so it changes when the data does.

If the config cannot be read the fetch throws, and `ScheduleStore.refresh()` falls back to cache as
it already does for any network failure — no guessing at a year.

The URL now exists in exactly one place, because the widget's duplicate fetch went with it (§5).

---

## 3. iOS silently ignores confirmed session end times

The `SessionEndConfirmer` / OpenF1 feature — polling for authoritative `SESSION FINISHED` records so
a session that overruns does not flip to "finished" early — is **wired up on macOS and the widget,
and dead on iOS.**

| call site | passes confirmed end dates? |
|---|---|
| `NoSpoilers/ContentView.swift:119` (`weekendView`) | yes |
| `NoSpoilers/ContentView.swift:131` (`headerCard`) | **no** |
| `NoSpoilers/ContentView.swift:178` (`sessionCard`) | **no** |
| `NoSpoilersMac/ContentView.swift:173` (`sessionRow`) | yes |
| `NoSpoilersWidget.swift:60` (`sessionState`) | yes |

Both resolver entry points default the parameter (`RaceWeekendResolver.swift:38`,
`SessionStatus.swift:22`), so omitting it compiles clean and reads as intentional.

Two consequences:

- The iOS session list and header use the grace-period estimate even when the real end time is known
  and sitting in shared `UserDefaults`.
- `weekendView` and `headerCard` compute `isFinished` from **different inputs on the same screen**.
  During an overrun the header can say "weekend complete" while the body still shows a live session,
  or the "coming up next" card can appear and disappear inconsistently.

A defaulted parameter is the wrong shape for a value that every correct call site must supply.
Consider removing the defaults so omission is a compile error.

### What was done — `f324f58`

Every iOS call site now passes the confirmed end dates, and the defaults are gone from both
`RaceWeekendResolver` and `SessionResolver.status` — including the `nextSession` default — so
omission is a compile error rather than a silent shrug. `SessionEndConfirmer` passes `nil`
explicitly and says why: it has already filtered out every session it has a confirmed end for.

`headerCard` no longer resolves "is this weekend over" for itself. `weekendView` resolves it once
and passes it down, which removes the disagreement rather than just aligning the two inputs.

---

## 4. Rescheduled sessions never reload the widget

`NoSpoilersCore/Sources/NoSpoilersCore/ScheduleStore.swift:89`

```swift
let changed = weekends.map(\.round) != self.weekends.map(\.round)
self.weekends = weekends
if changed { WidgetCenter.shared.reloadAllTimelines() }
```

The change test compares **round numbers only**. A session moved by an hour, a weekend rescheduled,
or a race cancelled in place all leave the round list identical, so `changed` is `false` and the
widget is never told. `RaceWeekend` is `Hashable` and the sessions are part of it — comparing the
weekends themselves is both simpler and correct.

This is the staleness half of task 19 arriving from the other direction, and it blocks task 07:
cancelled-race handling cannot work if the feed change that marks the cancellation does not trigger a
reload.

### Also on the refresh path

**Three refreshes fire on launch** — `ScheduleStore.swift:30` (from `init`),
`ContentView.swift:67` (`.task`), and `ContentView.swift:79-83` (`scenePhase == .active`). They
overlap, and `isRefreshing` has no reentrancy guard: `ScheduleStore.swift:84-85` sets the flag and
clears it in a `defer`, so the first completion clears it while the other two are still in flight.
On iOS that flag gates the skeleton view (`ContentView.swift:33`), so the skeleton can disappear
before there is anything to show.

`setupRefreshTimer` (`ContentView.swift:396-406`) reschedules itself from inside its own sink. It
works, but the comment "reschedule in case the interval changed" overstates it: in the hourly branch
the interval is only re-evaluated once an hour, so a session starting 59 minutes after a check is
noticed late.

### What was done — `eab2856`

`weekends != self.weekends`, one line, plus tests covering a reschedule, a cancellation, and the
no-change case — including one that demonstrates what the round-number comparison missed, so nobody
reintroduces it as a cheaper equivalent.

Concurrent `refresh()` callers now join the fetch in flight instead of starting their own, which
fixes the overlapping-launch-refresh problem at its source rather than by guarding the flag.

`refreshInterval()` no longer returns a flat hour when idle: it wakes early enough to catch the next
session entering the imminent window. The thresholds are named constants, and the misleading comment
is corrected.

---

## 5. The same logic implemented three and four times

Per `.claude/rules/core.md`, these are correctness findings, not style.

**"When did this session end" — three answers.**

| | source |
|---|---|
| `NoSpoilers/ContentView.swift:324`, `:338` | raw `session.endsAt` |
| `NoSpoilersMac/ContentView.swift:202` | raw `session.endsAt` |
| `NoSpoilersWidget.swift:47` `effectiveSessionEndDate` | confirmed end, else `endsAt + gracePeriod` |

`session.endsAt` is `startsAt + kind.defaultDuration` (`Session.swift:11`) — the *scheduled* end. Both
apps therefore label a finished race "finished 1h 40m ago" at the moment the widget considers it just
over, because the race grace period is 90 minutes (`SessionKind.swift:55`). The widget's version is
the correct one; it belongs in `NoSpoilersCore` next to `SessionResolver`, with both apps calling it.

**Countdown formatting — four implementations**, each with different granularity:

- `NoSpoilers/ContentView.swift:353` — days/hours, hours/minutes, minutes. No seconds.
- `NoSpoilersMac/ContentView.swift:216` — adds a seconds tier and shows seconds throughout.
- `ScheduleStore.swift:68-75` (`menuBarLabel`) — a third set of tiers.
- The widget uses `Text(date, style: .relative)` and formats nothing.

Three of the four already sit behind `Strings` entries, so the divergence is baked into the string
tables as well.

**The widget re-implements the feed fetch.** `NoSpoilersWidget.swift:76-78` declares its own
`WidgetFeedResponse`, `:102` its own URL, `:106-119` a `DispatchSemaphore` to make it synchronous —
all duplicating `ScheduleFetcher`. `getTimeline` takes a completion handler, so a `Task` that calls
`ScheduleFetcher` and completes from there would remove both the duplicate and the semaphore.

**`endTime(of:)` is copied verbatim** into `NoSpoilers/ContentView.swift:314-317` and
`NoSpoilersMac/ContentView.swift:107-110`. See [§6](#6-fail-fast-violations) — both copies are also
wrong in the same way.

### What was done — `80d6de8`, plus the widget fetch in `8614934`

`SessionResolver.effectiveEndDate` in `NoSpoilersCore`, called by all three surfaces. Both apps were
counting "finished N ago" from `session.endsAt`, so a finished race read "finished 1h 40m ago" the
moment it flipped.

`endTime(of:)` is now `RaceWeekendResolver.effectiveEndDate(of:confirmedEndDates:)` — once, with the
sentinel replaced (§6).

Countdown formatting was consolidated **as arithmetic, not as output**. `DurationBreakdown` holds
the decomposition that was written out five times; which tiers each surface shows stays at the call
sites, because that part is a genuine per-surface product decision — the menu bar has one line, the
macOS popover is open in front of you and ticks in seconds, iOS is glanced at and stops at minutes.
Those differences are now commented where they are made instead of being implied by five copies of
the same modulo expressions. `totalHours` is deliberately separate from `hours` so "finished 48h
ago" still reads 48h.

The widget's duplicated fetch is gone entirely — its `WidgetFeedResponse`, its URL, and its
`DispatchSemaphore`. `getTimeline` takes a completion handler, so it awaits instead of blocking. The
8-second bound the widget used to impose moved into `ScheduleFetcher` rather than being lost.

---

## 6. Fail-fast violations

Against the `CLAUDE.md` rule: never return a sentinel, never `?? defaultValue` over a missing
resource, crash instead.

- **`endTime(of:)` returns `.distantPast`** (`NoSpoilers/ContentView.swift:315`,
  `NoSpoilersMac/ContentView.swift:108`) when a weekend has no sessions. Both call sites already
  filter `!allSessions.isEmpty` first (`ContentView.swift:302`, `NoSpoilersMac/ContentView.swift:102`),
  so the sentinel is unreachable — it should be a `precondition` or a force-unwrap, and it should
  exist once rather than twice.
- **`RaceWeekend.countryCode` returns `""`** for an unrecognised GP name (`RaceWeekend.swift:45`), and
  **`countryFlag` returns `"🏁"`** (`RaceWeekend.swift:49-50`). Meanwhile `ScheduleStore.swift:49`
  and `:53` `precondition` that the country code is non-empty. The codebase treats the same condition
  as a programming error in one file and papers over it in another. A renamed or new Grand Prix in a
  future calendar silently renders a blank flag — and note this is reachable via
  [§2](#2-the-apps-stop-working-on-1-january-2027).
- **`NoSpoilersWidget.swift:115`** — `?? []` swallows a decode failure, and `:131` then writes that
  empty array back over the cache. A corrupt-cache-plus-failed-network path overwrites the file with
  a known-bad value.

### What was done — `8614934`, `80d6de8`

The `.distantPast` sentinel is a `preconditionFailure` naming the filter the caller skipped, and it
exists once instead of twice. The widget's `?? []` is gone with the duplicate fetch, and only a
successful fetch is written back to the cache now.

**The country-code finding turned out to be live, not hypothetical.** Round 16 of the 2026 feed is
`"Bahrain Grand Prix (Malaysia)"`, at Sepang. It matches nothing in `countryCode`'s switch, so it
returned `""` — and `ScheduleStore` preconditioned on the code being non-empty. That combination was
a scheduled crash: the macOS menu bar app would have died from around 27 September, when that round
became the next session.

The fix went the opposite way to what this file suggested. A Grand Prix the app cannot identify is
*possible* data — the feed is not ours and its naming changes — so it is modelled rather than
asserted away. `countryCode` is now `String?`, the preconditions are gone, and `FlagImage` takes the
optional and renders the chequered flag for nil. `countryFlag`, the other `"🏁"` sentinel, was dead
code and was deleted.

**Still open, and a product call rather than a code one.** No guess is made about which country the
feed means by that name. Location Sepang and the parenthetical both point at Malaysia, but the entry
looks provisional and the round currently renders with a chequered flag instead of one. Either the
feed corrects itself before 2 October, or someone decides to map it.

---

## 7. Smaller items

- **Two separate `.onAppear` blocks** on the same view (`NoSpoilers/ContentView.swift:61` and `:84`).
- **`selectedWeekendIndex` is never clamped or re-homed.** `weekendsLoaded` latches `true` on first
  load (`:64`, `:72`) and the index is never recomputed. Leave the app open across a weekend ending
  and it stays on the stale page; if `weekends` ever shrinks, the selection matches no `.tag` at all.
- **`log.error(...)` is used for routine informational logging** throughout the widget
  (`NoSpoilersWidget.swift:89`, `:96`, `:126`, `:132`). It works — it is why the task 19 measurements
  were readable — but it puts normal operation in the error log. Worth a deliberate decision either
  way rather than leaving it accidental.
- **24 page dots, and swipe is the only navigation.** There is no "jump to current weekend"
  affordance, so when the gesture in §1 fails the user has no alternative route. Worth considering
  alongside the §1 fix rather than after it.

### What was done — `8614934`, `a4f58cc`

The two `.onAppear` blocks are one. Selection is homed and clamped in a single place, so a schedule
that shrinks can no longer leave the pager on a page no `.tag` matches. Routine widget logging moved
from `log.error` to `log.info`.

The missing navigation affordance was built: a "Current" button in the top bar, shown only once you
have navigated away from the current weekend. It is the mitigation for §1's failure mode — with
swipe as the sole route between 23 pages, a gesture that does not take left no way back.

---

## Suggested order

1. §1 swipe — the reported bug, small, self-contained.
2. §4 the `changed` comparison — one line, and it unblocks task 07.
3. §3 iOS confirmed end dates — a shipped feature that does nothing on one platform.
4. §2 season rollover — needs a decision on rollover policy before it needs code.
5. §5 / §6 — convergence work; best done as one pass, since §5's end-time consolidation and §6's
   sentinel removal touch the same two duplicated helpers.

## Verification

Run at the end of the last commit:

| command | result |
|---|---|
| `scripts/verify-core-tests.sh` | 28 tests, 0 failures (11 new) |
| `scripts/verify-ios-build.sh` | BUILD SUCCEEDED |
| `scripts/verify-widget-build.sh` | BUILD SUCCEEDED |
| `scripts/verify-mac-build.sh` | BUILD SUCCEEDED |

The new fetch path was also run against the live feed rather than only compiled: 23 weekends, rounds
1-23, all 2026, and round 16 — the unmapped one — resolves an end date instead of crashing.

Not covered by any of that, and listed again because a green build is not evidence for either:

- the §1 swipe fix, which needs a hands-on gesture pass
- widget timeline latency after the fetch change. The cache-hit path is untouched, so task 19's
  0.354s should hold, but the cache-miss path now makes two requests where it made one.

## Related

- **Task 07** — blocked by §4.
- **Task 19** — §4 is the same staleness concern from the app side; §5's widget-fetch duplication is
  in the file that task touched.
- **Task 20** — widget install prompt; §1's missing navigation affordance is adjacent.

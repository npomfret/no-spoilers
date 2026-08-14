# Task 21: app code review — swipe navigation, season rollover, and shared-logic drift

**Status:** TODO
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

---

## Suggested order

1. §1 swipe — the reported bug, small, self-contained.
2. §4 the `changed` comparison — one line, and it unblocks task 07.
3. §3 iOS confirmed end dates — a shipped feature that does nothing on one platform.
4. §2 season rollover — needs a decision on rollover policy before it needs code.
5. §5 / §6 — convergence work; best done as one pass, since §5's end-time consolidation and §6's
   sentinel removal touch the same two duplicated helpers.

## Related

- **Task 07** — blocked by §4.
- **Task 19** — §4 is the same staleness concern from the app side; §5's widget-fetch duplication is
  in the file that task touched.
- **Task 20** — widget install prompt; §1's missing navigation affordance is adjacent.

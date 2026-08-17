# Task 19: the widget builds a timeline for the whole season, and shows grey bars while it does

**Status: FIXED 2026-08-14. Measured before and after on the same machine: 133 entries and 3.400s
became 4 entries and 0.354s. The last open item — the reload had been reasoned from the policy and
never watched firing — was closed on 2026-08-17; see "How the reload was finally observed" below.
The only thing still unproven is the horizon's 48-hour **duration**, which needs a soak. The
arithmetic it was reasoned from is now unit-tested in `TimelinePlannerTests` (task 25).**

The widget takes **3–6 seconds** to produce its first timeline. SpringBoard gives up waiting well
before that and keeps showing the redacted placeholder — the app's own layout drawn as grey bars.
On a real device that is what a user sees after every reboot, and after every widget reload that
misses the cache.

This was mistaken for a broken widget twice in one morning, by two different people looking at two
different simulators. It is not broken. It is slow, and slow renders as blank.

---

## Measured, 2026-08-13

Both simulators, current build, cache already warm — so none of this is network time.

```
iPhone 11 Pro Max (23 weekends)
  10:26:55.456  cache hit: 23 weekends
  10:26:58.345  Request ended for NoSpoilersWidget:systemLarge - success     2.9s
  10:27:03.890  SpringBoard: Received content confirmation action error: timeout
  10:27:04.498  SpringBoard: Received content confirmation action error: timeout

iPhone 17 (22 weekends)
  10:35:59.461  cache hit: 22 weekends
  10:36:05.321  Request ended for NoSpoilersWidget:systemLarge - success     5.9s
```

The timeline request **succeeds** in both cases. The failure is entirely one of latency: the
content confirmation times out at roughly 3 and 4 seconds, and the placeholder stays on screen.

**The `ExcUserFault_NoSpoilersWidgetExtension` reports in `~/Library/Logs/DiagnosticReports/` are
not this, and are not anything.** Six of them were generated this morning. Every frame is Apple
framework code —

```
libxpc  _XPC_MISUSE_FAULT → xpc_connection_copy_bundle_id
BaseBoard  _BSBundleIDForXPCConnectionAndIKnowWhatImDoingISwear
BoardServices  +[BSXPCServiceConnectionPeer peerOfConnection:]
```

— there is no app code on the stack, and the process carried on and completed its timeline
afterwards. Do not spend time on them.

---

## Cause

`timelineBoundaryDates` (`NoSpoilers/NoSpoilersWidget/NoSpoilersWidget.swift:228-264`) emits a
boundary for **every remaining session start, every remaining session end, and a 24-hour expiry per
weekend, across the entire season**. `getTimeline` then maps `makeEntry` over all of them
(`:283-290`), and WidgetKit archives a complete SwiftUI view for each entry.

Counted against the real feed as of 2026-08-13, mid-season:

```
weekends 22 · sessions 110 · future session starts 55
boundary candidates ≈ 55 starts + 55 ends + 22 expiries ≈ 132
```

So ~130 archived views per timeline request, and the count is highest in March and falls to nothing
in December — which means **the same code is fast in the off-season and slow at the start of a
season**, and slowest exactly when the app matters most.

### A second bug is hiding in the same place

The reload policy is `.atEnd` (`:289`). With entries running to the final race, `.atEnd` is
December. Nothing in the timeline asks the widget to look at the cache again before then.

Reloads do still happen — `ScheduleStore.refresh()` calls
`WidgetCenter.shared.reloadAllTimelines()` when the schedule changes
(`NoSpoilersCore/Sources/NoSpoilersCore/ScheduleStore.swift:91`) — **but only while the app is
running.** For a product whose whole point is that you never open the app, that is the wrong
dependency: a user who adds the widget and never launches the app again gets a timeline computed
once and never revisited. Rescheduled sessions and cancelled races (task 07) would not appear.

*Reasoned from the code, not yet measured.* Confirm before fixing, because the fix for the latency
problem changes this behaviour too and the two must not be conflated.

---

## The shape of the fix

Cap the timeline at a **horizon**, not at the end of the season. The widget only ever displays the
current or next weekend, so entries beyond a day or two are archived views nobody will ever see.

Roughly: keep boundaries within the next ~24–48 hours, cap the entry count, and set
`.after(horizon)` so the widget comes back for more. That fixes the latency and the staleness in one
change, and it makes the cost independent of where in the season you are.

**Do not fix this by making the entry view cheaper.** The entry view is fine; there are simply two
orders of magnitude too many of them.

**Do not fix this by widening `SETTLE_SECONDS` in `scripts/screenshots.py`.** That hides the
symptom on the one machine that takes screenshots and leaves it in front of every user.

Open question worth settling first: whether the horizon should be a duration or a count. A duration
is more predictable in the off-season (no entries at all, so `.after` carries it); a count bounds
the worst case directly. Pick one and write down why.

---

## What was done, 2026-08-14

**Decided: a duration, with a count as a backstop.** The horizon is also the reload date, so
bounding it in time bounds staleness directly and predictably. A count would leave the reload date
dependent on how densely the feed happens to be packed at that moment — dense during a race
weekend, empty for the five days between — and in the off-season it would leave no reload date at
all. `maxTimelineEntries = 24` is a backstop against a feed that is not what we think it is, not
the working limit: inside 48 hours the real feed produces at most ~13 boundaries.

`NoSpoilers/NoSpoilersWidget/NoSpoilersWidget.swift`:

- `timelineHorizon = 48 * 3600` and `maxTimelineEntries = 24`, both private to the widget. They are
  WidgetKit timeline policy with one consumer, so they do not belong in `NoSpoilersConfig`.
- `timelineBoundaryDates(after:upTo:data:)` takes a horizon and drops every candidate beyond it.
  The three `> now` checks became one `appendIfWithinHorizon` — the bound has to hold for all three
  kinds of boundary, so having it in one place is what stops the next one being added without it.
- `getTimeline` reloads with `.after(horizon)` instead of `.atEnd`, and at the last kept boundary
  instead if the cap truncated the list.

**Two things found while fixing it, both in the code that was replaced.**

`timelineBoundaryDates` seeds `candidates` with `now`, so it can never return an empty array — the
`entries.isEmpty ? .after(now + 900) : .atEnd` ternary could only ever take the `.atEnd` branch.
**The documented 900-second off-season fallback was unreachable.** What the off-season actually got
was `.atEnd` on a single entry dated `now`, i.e. a reload date already in the past. The verification
box below has been rewritten accordingly; the old one asked for behaviour that never existed.

The `precondition` in `getTimeline` is that invariant made explicit, per the repo's fail-fast rule:
an empty timeline would render nothing at all, and that is a programming error rather than a state
to handle.

### Measured

Same machine, same device (`iPhone 17`, `E92811F0`), same 23-weekend cache seeded from the live
feed, ten minutes apart, `systemLarge`. `cache hit` to `Request ended` is the same interval the
numbers at the top of this file measure.

| | entries | cache hit → request ended | timeline spans to |
|---|---|---|---|
| before | 133 | **3.400s** | 2026-12-07 |
| after | 4 | **0.354s** | 2026-08-15 |
| after, off-season | 1 | **0.122s** | — |

The before run was taken by stashing the change and rebuilding, not from the 2026-08-13 figures at
the top — those were a different day and a different Xcode, and would not have been a comparison.

`scripts/screenshots.py` seeds a 3-weekend fixture, which is correct for a screenshot and useless
here: the cost scales with remaining sessions, so that fixture is fast before and after and proves
nothing. The measurement seeds the live feed instead.

---

## Verification

- [x] Timeline request completes in well under a second with a full-season cache, measured the same
      way as above (`log show --predicate 'process == "NoSpoilersWidgetExtension"'`) — 0.354s
- [x] No `content confirmation action error: timeout` from SpringBoard after a boot
- [x] The widget renders real content, not grey bars, within `SETTLE_SECONDS` of a cold boot —
      captured at 12s on a 23-weekend cache: Dutch GP R12, five live countdowns, next-up Italian GP
- [x] The widget updates across a session boundary without the app being launched — **watched
      firing on 2026-08-17**, both halves. See "How the reload was finally observed" below. What is
      still *not* proven is the 48-hour horizon **duration**; the mechanism was proven at ~9 minutes.
- [x] Off-season: one entry, 0.122s, and no reload storm over 60 seconds. **Not "unchanged"** — the
      900s fallback this box used to ask for was dead code, and the real previous behaviour was a
      reload date in the past. It is now `.after(horizon)` like every other case.
- [x] `scripts/verify-widget-build.sh` passes

---

## How the reload was finally observed, 2026-08-17

Both halves were watched on `iPhone 17` (`E92811F0`, iOS 26.4), app never launched at any point.

**A session boundary crosses from the archive.** Fixture with the race 90 minutes out, host clock
moved +2h. The race row went from a `1 hr, 28 min` countdown to a red **In Progress** badge, and the
extension never woke — no data read in the log across the whole window. The swap came entirely from
the entry archived at the race-start boundary.

**`.after(reloadAt)` fires, and the rebuild re-reads the cache.** A fixture of 40 sessions at 10s
spacing produces ~89 boundaries against `maxTimelineEntries`, so `getTimeline` takes the truncated
branch and the reload date becomes the 24th boundary — about nine minutes out instead of 48 hours.
Seconds before it fell due, the App Group cache was swapped for a single round 20 Hungarian weekend,
which appears in **no** archived entry. At the reload date the widget was showing round 20. The only
way to draw it is a fresh `getTimeline` that re-read the cache.

That run is also the first time `reloadAt = kept.last!` has ever executed — the real feed produces
~4 entries against a cap of 24, so the truncated branch had never been reached in production or in
testing.

### Two things this cost a morning to learn — read them before re-testing

- **A clock shift cannot test the reload.** chronod schedules on elapsed time and ignores wall-clock
  jumps: moving the host clock an hour past a live reload date produced nothing, twice, while the
  archived entries kept advancing correctly. Entry *selection* follows the wall clock; timeline
  *regeneration* does not. Shifting the clock also breaks `sudo` mid-run, because sudo validates its
  cached credential against the wall clock — authenticate a root helper **before** the first shift.
- **`log.info` is not written to the log store.** `resolveWidgetData` logs `cache hit` at info level,
  which lives briefly in the memory buffer and is gone by the time `log show` asks — with or without
  `--info`. Two experiments were scored as "no reload" on absent log lines while the widget was
  visibly doing the right thing on screen. Until those lines are `.notice`, **trust the screen over
  the log**, and assert that a *build* happened before concluding anything about a *reload*.

---

## Related

- **`scripts/screenshots.py`** — this is why the screenshot pipeline needs a `SETTLE_SECONDS` delay
  at all, and why a run can capture a grey widget that looks like a rendering bug. See the App Store
  screenshots section of `docs/guides/building.md`, which records that the delay must not be widened
  to paper over this.
- **Task 16** — the listing has to show the widget working. A screenshot of the placeholder is
  worse than no screenshot.
- **Task 07** — cancelled-race handling is downstream of the staleness half of this.

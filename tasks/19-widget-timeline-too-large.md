# Task 19: the widget builds a timeline for the whole season, and shows grey bars while it does

**Status: OPEN, found 2026-08-13 while capturing App Store screenshots. Not yet fixed.**

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

## Verification

- [ ] Timeline request completes in well under a second with a full-season cache, measured the same
      way as above (`log show --predicate 'process == "NoSpoilersWidgetExtension"'`)
- [ ] No `content confirmation action error: timeout` from SpringBoard after a boot
- [ ] The widget renders real content, not grey bars, within `SETTLE_SECONDS` of a cold boot
- [ ] The widget still updates across a session boundary without the app being launched
- [ ] Off-season behaviour unchanged — still reloads on the 900s fallback
- [ ] `scripts/verify-widget-build.sh` passes

---

## Related

- **`scripts/screenshots.py`** — this is why the screenshot pipeline needs a `SETTLE_SECONDS` delay
  at all, and why a run can capture a grey widget that looks like a rendering bug. See the App Store
  screenshots section of `docs/guides/building.md`, which records that the delay must not be widened
  to paper over this.
- **Task 16** — the listing has to show the widget working. A screenshot of the placeholder is
  worse than no screenshot.
- **Task 07** — cancelled-race handling is downstream of the staleness half of this.

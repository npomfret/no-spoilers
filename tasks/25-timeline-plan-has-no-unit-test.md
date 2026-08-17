# Task 25: the widget's timeline plan cannot be unit tested

**Status: DONE 2026-08-17.** `TimelinePlanner` and `TimelinePlan` are in `NoSpoilersCore` with `now`
as a parameter, and `TimelinePlannerTests` covers the nine cases listed below. `buildTimeline` no
longer decides any date: it fetches, maps planned moments to entries, logs, and hands the plan's
`reloadAt` to `.after(_:)`.

**Evidence.** `scripts/verify-core-tests.sh` 47 tests / 0 failures, up from 38. All three build
wrappers `BUILD SUCCEEDED`. The tests were mutation-checked rather than trusted for passing first
time — dropping the truncation case from the reload choice fails 2, making the horizon exclusive
fails 1. End to end on `iPhone 17` (`E92811F0`, iOS 26.4), the `timeline built` line is unchanged
against the same fixture, before and after:

```
1.1.1  {"now":"...09:29:48Z","weekends":3,"boundaries":4,"entries":4,"truncated":false,"reloadAt":"...09:29:48Z"}
1.1.2  {"now":"...09:49:28Z","weekends":3,"boundaries":4,"entries":4,"truncated":false,"reloadAt":"...09:49:28Z"}
```

Two things fell out of the run that are worth keeping. `WidgetDataSnapshot.allSessions` existed only
to feed the boundary computation, so it left with it and the type is now the two fields it always
was. And an intermediate build made with `CODE_SIGNING_ALLOWED=NO` — which strips the App Group
entitlement, exactly as `screenshots.py:ensure_installed` warns — produced
`{"msg":"cache load failed","error":"containerUnavailable"}` and named its own cause in one line.
Before this week that build would have silently served the network and looked fine.

**What follows below is the case as it was argued before the work, kept because the reasoning is the
part worth re-reading.**

## The defect

`NoSpoilersTimelineProvider.buildTimeline` calls `Date()` inside itself, and everything it decides
follows from that call. The horizon, which boundaries fall inside it, whether the cap truncated, and
which of two reload dates `.after` is given are all computed from a value no caller can supply.

The consequence is not a style complaint. **This is the one piece of logic in the product whose
failures are invisible**: a widget with the wrong reload date shows stale content silently, the app
is not running, and there is nothing attached to watch it. Task 19 needed a 40-session fixture, a
booted simulator, a swapped App Group cache and a nine-minute wait to observe one branch of a
two-line expression. A test with an injected `now` would assert the same thing in milliseconds.

The proof it matters: `reloadAt = kept.last!` — the truncation branch — **had never executed** in
production or in testing before 2026-08-17. The real feed produces ~4 boundaries against a
`maxTimelineEntries` of 24, so nothing had ever taken it. It was reached only by constructing a
fixture designed to force it. Untested code that had never run and contains a `!` is exactly the
shape that eventually crashes an extension nobody is watching.

## What the counter-argument was, and why it does not hold

The case against was that WidgetKit already hands the provider its own `Context` and that anything
worth asserting is observable from the log line now added at `.notice`. That is true of *whether it
happened* and false of *whether it was right*: a trace shows the reload date that was chosen, and
cannot show that a different one should have been. It also only works after the fact, on a device,
with someone already suspicious.

## The scope, kept deliberately tight

Move into `NoSpoilersCore`, taking `now` as a parameter:

- `timelineBoundaryDates(after:upTo:data:)`
- the plan computation: the prefix against the cap, the `truncated` flag, and the `reloadAt` choice

Leave in the widget target:

- `makeEntry` and everything view-shaped
- the two policy constants, `timelineHorizon` and `maxTimelineEntries`, which are WidgetKit's
  limits and not domain facts

**This is a parameter, not a protocol.** Do not add a `Clock`, a `DateProvider`, or a `TimeSource`
abstraction. There is one function that needs the current moment and one caller that has it; a
protocol for that is an abstraction family the repo does not have and would need a proposal under
`.claude/rules/core.md`. `SessionResolver.status(for:at:nextSession:confirmedEndAt:)` is the
established pattern here — it already takes `at now: Date` for precisely this reason, and it is
tested precisely because it does.

The return type wants naming. A small `TimelinePlan { boundaries: [Date], reloadAt: Date,
truncated: Bool }` keeps the assertion readable and stops the widget re-deriving `truncated` to log
it.

## What the tests should pin

- The cap truncates and `reloadAt` becomes the last boundary kept, not the horizon
- Under the cap, `reloadAt` is the horizon exactly
- Off-season: one boundary, `now`, and a reload at the horizon rather than a date in the past
- A boundary exactly on the horizon — inclusive or exclusive, currently unstated
- The seeded current moment is always present, which is what the existing `precondition` asserts at
  runtime and nothing asserts at build time

## What this does not close

The 48-hour horizon **duration** still has no proof. A unit test pins the arithmetic; only a soak
shows that WidgetKit honours a reload date two days out. That stays open in task 19.

## Related

- `tasks/19-widget-timeline-too-large.md` — the observation this was waiting on, and the two traps
  that made it expensive
- `docs/guides/swift-patterns.md` — the pattern-governance rules this scope is drawn to satisfy

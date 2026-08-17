# Task 26: three network call sites, two session policies, one of them written down

**Status: OPEN. Noticed on 2026-08-17 while doing task 24, and deliberately not fixed there — it is
a different question from "why did that fail silently", and folding it in would have buried it.**

`ScheduleFetcher` bounds its requests, with a reason in the source. The other two call sites use
`URLSession.shared` and inherit whatever Apple ships. Neither of them decided that; they just never
said anything.

```
ScheduleFetcher     ephemeral   request  8s   resource  20s   NoSpoilersCore
OpenF1Client        .shared     request 60s   resource   7d   NoSpoilersCore
UpdateChecker       .shared     request 60s   resource   7d   NoSpoilersMac
```

The 60s / 7d figures are measured, not assumed — `URLSession.shared.configuration` on macOS 26.5
reports `timeoutIntervalForRequest 60.0`, `timeoutIntervalForResource 604800.0`.

## Why the existing reasoning does not simply transfer

`ScheduleFetcher`'s comment gives two reasons, and **only one of them generalises**:

- *"Apple advises against `.shared` in extension contexts"* — specific to that type. It is the only
  one of the three that runs in the widget extension (`NoSpoilersWidget.swift:102`). The OpenF1
  polling loop is app-only; the widget reads confirmed ends through the `nonisolated static`
  `SessionEndConfirmer.loadStoredDates`, not by polling. `UpdateChecker` is the menu-bar app.
- *"a widget stuck waiting on a hung request shows grey bars"* — that is the 8-second bound, and it
  is about WidgetKit's patience, not about the network being slow. It does not argue for 8 seconds
  anywhere else.

So this is not "two sites forgot to copy a rule". It is that nobody has decided what the rule is
away from the widget.

## What the defaults actually cost, per site

**`OpenF1Client` — real, and it undercuts the point of the feature.** `SessionEndConfirmer.pollLoop`
walks its pending sessions **sequentially**, awaiting each, and only then sleeps 120 seconds. A hung
request therefore does not merely delay one lookup, it stretches the whole cycle: with two pending
sessions and both requests timing out at 60s, the loop runs every four minutes instead of every two.
The confirmer exists to retire an "In Progress" badge up to 90 minutes early on a race; a cadence
that silently doubles on a bad network is directly against that. `.error` lines now appear when a
request fails outright (task 24), but a *slow* request still says nothing at all.

**`UpdateChecker` — small.** One request at launch, no UI blocked, and the outcome is now logged
either way. A 60-second ceiling on a check nobody is waiting for is defensible; it just is not
written down as a choice.

**Not measured:** whether a request to either host has ever actually taken longer than 8 seconds.
Worth knowing before picking a number, because a bound tighter than the real tail turns a slow
network into a failed one — and for the confirmer, a failed lookup is a session that stays "In
Progress" for its full grace window. Do not tighten these by eye.

## The decision

One policy or three? Today it is one policy and two omissions, which is the worst of the three
options because it reads as intentional.

**Recommended: hoist the configured session into `NoSpoilersCore` and have all three use it.** It is
the convergence the repo rules ask for — one concern, one approved implementation — and the
configuration that already exists is the only one anybody thought about. Ephemeral costs the other
two nothing, since `ScheduleCache` is the caching layer and neither of them wants a URL cache.
Timeouts become a stated policy with one place to change them, and a site that needs different ones
overrides it and says why. It has to be `public` for `UpdateChecker` to reach it from the Mac target.

**Cheaper: leave the sessions alone and write a sentence at each `.shared` site** saying the default
timeouts are accepted and why. That closes the "reads as intentional" half at no risk, and leaves
the poller's stretched cadence exactly as it is.

**Argument against converging that should be recorded:** `URLSession.shared` shares a connection
pool and cookie storage with the rest of the process, and three bespoke sessions mean three pools.
Here that is worth nothing — the three call sites talk to three different hosts (`raw.
githubusercontent.com`, `api.openf1.org`, `api.github.com`) and none of them reuses a connection
from another.

## Check while in there

`ScheduleFetcher()` is constructed fresh at each call site — `ScheduleStore.performRefresh` and the
widget's `resolveWidgetData` — and the session is a `private let` on the instance, so **every refresh
builds a new `URLSession`**. Whether that matters is unverified: a session with no delegate does not
have the classic retain cycle and should deallocate normally. But if the configured session becomes a
shared `static let`, this stops being a question, which is a second small argument for the
recommendation above.

## Verification

Nothing here changes behaviour that the existing tests can see. `scripts/verify-core-tests.sh` plus
the three build wrappers cover the refactor; the timeouts themselves need either a measurement
against both hosts or a deliberate statement that the numbers are a policy rather than a finding.

## Related

- Commits `a98c7da` and `5798697` — task 24, the pass this was found during, and the reason
  `OpenF1Client` now says anything at all when a request fails. The task file was deleted on
  completion; the commit messages carry what it concluded.
- `tasks/19-widget-timeline-too-large.md` — where the 8-second bound comes from, and what a widget
  waiting on the network looks like to a user
- `docs/guides/swift-patterns.md`, "Networking" — the rules the fetch sites already share

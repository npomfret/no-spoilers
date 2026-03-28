# Task 09: Session Overrun Status Handling

**Status:** TODO
**Depends on:** None
**Effort:** ~2-4 hours
**Priority:** High for real race-weekend correctness

## Goal

Prevent the app from showing an F1 session as finished when the real-world event is still running past its scheduled duration.

The product requirement is conservative: if we do not know that a session has definitely ended, we should not show `Finished`.

## Problem Summary

The current code derives session end times locally from a fixed default duration per session kind:

- `Session.endsAt = startsAt + kind.defaultDuration`
- practice and qualifying are treated as one hour
- sprint qualifying is treated as 45 minutes
- sprint is treated as 30 minutes
- race is treated as two hours

That is only a scheduled estimate. It is not a confirmed finish time.

F1 sessions routinely overrun:

- races can extend beyond two hours because of safety cars, red flags, restarts, or weather
- qualifying can run long due to stoppages
- sprint sessions can slip as well

When that happens, the app can currently cross the synthetic `endsAt` threshold and start saying a session is finished even though it is still live.

## Why This Happens

The status decision is based on the derived `endsAt` value in multiple places.

### Shared model

- `NoSpoilersCore/Sources/NoSpoilersCore/Session.swift`
  - `endsAt` is computed from `kind.defaultDuration`

### Widget

- `NoSpoilers/NoSpoilersWidget/NoSpoilersWidget.swift`
  - `sessionState(for:at:)` returns `.finished` when `session.endsAt < now`
  - `makeEntry(at:)` chooses the current weekend by checking for any session with `endsAt >= now`
  - `nextReloadDate(after:)` reloads on `current.endsAt`

### macOS menu bar and popover

- `NoSpoilersCore/Sources/NoSpoilersCore/ScheduleStore.swift`
  - menu bar label considers a session live only while `now < endsAt`
- `NoSpoilers/NoSpoilersMac/ContentView.swift`
  - popover row styling and badges mark sessions done when `endsAt < now`
  - current weekend selection also depends on `endsAt >= now`

This is the same concern implemented across multiple surfaces, all relying on the same weak assumption.

## User-Visible Failure Mode

Example:

1. Race start is scheduled for 14:00.
2. The app synthesizes race end as 16:00.
3. A red flag pushes the race past 16:00.
4. At 16:01 the app can:
   - show `Finished`
   - stop showing `LIVE`
   - advance the widget timeline as if the session is over
   - treat the weekend as past sooner than it should

That is a correctness bug. It violates the product's spoiler-safe contract because the user is being told a session has completed when it may still be in progress.

## Constraint

The current feed is schedule-only. It gives us session start times, not authoritative live status or confirmed end times.

That means we cannot know the exact finish moment from the existing source.

We therefore need a conservative status model, not a precise one.

## Suggested Solution

Move session status resolution into a single shared boundary in `NoSpoilersCore` and stop treating scheduled duration expiry as proof of completion.

### Proposed model

Introduce a shared status resolver that returns something like:

```swift
enum ResolvedSessionState {
    case upcoming
    case live
    case overrunGrace
    case finished
}
```

The exact type name can follow the repo's existing naming once implementation begins, but the important point is one shared source of truth.

### Proposed rules

1. Before `startsAt`
   - status is `upcoming`

2. From `startsAt` until scheduled end
   - status is `live`

3. After scheduled end, do not immediately switch to `finished`
   - enter a conservative post-schedule state such as `overrunGrace` or `possiblyStillRunning`

4. Only mark `finished` when one of these is true
   - a configured grace window has elapsed beyond the scheduled end
   - the next session in chronological order has started

The second rule is important because if the next session has started, the previous one must be over for our product purposes.

### Why this is the right tradeoff

It is better to show a session as still live for slightly too long than to show it as finished too early.

False positive `Finished` states are more harmful than conservative lag because the user explicitly wants to avoid being told something has ended when it has not.

## Recommended Implementation Shape

Keep this logic out of the widget and app views.

### Step 1: Add a shared resolver in `NoSpoilersCore`

Introduce a small plain-Swift type responsible for:

- evaluating one session against `now`
- optionally looking at the next chronological session
- deciding whether the session is upcoming, live, in overrun grace, or finished

This boundary should own:

- the grace-window policy
- the transition rules
- the canonical definition of "current" versus "finished"

### Step 2: Replace direct `endsAt` comparisons

Update all current call sites to use the shared resolver instead of open-coding:

- `session.endsAt < now`
- `session.startsAt <= now && now < session.endsAt`
- `weekend.allSessions.contains { $0.endsAt >= now }`
- reload calculations that use `current.endsAt`

### Step 3: Keep presentation separate from resolution

UI surfaces can map shared states into their own labels:

- widget:
  - `live` -> `Now`
  - `overrunGrace` -> `Live`
  - `finished` -> `Finished`
- macOS popover:
  - `overrunGrace` should visually behave like live, not done
- menu bar:
  - overrun grace should prefer the live label rather than moving to the next session countdown

## Grace Window Recommendation

Start with a simple fixed grace window in the shared core.

Recommended first pass:

- practice / qualifying: 30 minutes beyond scheduled end
- sprint qualifying / sprint: 20-30 minutes beyond scheduled end
- race: 90-120 minutes beyond scheduled end

The exact values should be chosen once implementation begins, but the initial standard should be intentionally conservative.

If that feels too blunt, the first implementation can use:

- a session-kind-specific grace duration, defined beside `SessionKind`

Do not scatter these durations across UI code.

## Important Edge Cases

### Gap before next session

A long gap before the next scheduled session must not force the current session to `finished` immediately after its default duration expires.

### Reload timing

The widget currently reloads using `min(nextSession.startsAt, currentSession.endsAt)`.

That will become incorrect once we stop trusting synthetic end times. Reload policy should instead be derived from the shared resolver so that an active overrun period keeps the widget in the current session state.

### Weekend selection

The current weekend should not disappear just because the estimated end passed. Weekend relevance should be based on the resolved state, not raw `endsAt`.

### No exact truth source

This task does not produce perfect live-status accuracy. It produces conservative correctness:

- acceptable: a session appears live a bit longer than reality
- unacceptable: a session appears finished before reality

## Non-Goals

- Adding race results or any external status feed
- Attempting exact real-time live tracking
- Introducing separate status logic for widget and macOS

## Acceptance Criteria

- No UI surface marks a session `Finished` immediately when the synthetic scheduled duration expires
- Widget, menu bar, and macOS popover all use one shared status rule
- Overrun handling is conservative and consistent across platforms
- The current weekend remains visible while a session is plausibly still running
- The menu bar does not jump to the next session countdown while the current session is still within the shared overrun window
- Widget reload timing is based on the shared status model, not raw estimated end time alone

## Verification Plan

1. Add targeted unit tests in `NoSpoilersCore` for the shared resolver:
   - upcoming before start
   - live during scheduled duration
   - overrun grace after scheduled end
   - finished after grace window expires
   - finished when next session starts

2. Manual spot checks with synthetic timestamps:
   - race session 1 minute after scheduled end should not show `Finished`
   - race session well past grace window should show `Finished`
   - menu bar should keep current session state during grace
   - widget should not advance to next session at the synthetic end boundary

3. Real weekend validation:
   - confirm the app does not prematurely flip to finished if a session runs long

## Open Question

If a future data source provides authoritative live status or actual finish times, this task should extend the shared resolver to consume that source rather than replacing the UI contracts again.

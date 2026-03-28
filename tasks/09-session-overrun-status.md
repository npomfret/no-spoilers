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

```swift
public enum SessionStatus {
    case upcoming
    case inProgress   // scheduled window OR within grace period
    case finished
}
```

Three states only. The distinction between "scheduled live" and "grace period" is an internal resolver detail — both mean the same thing to the user: *something may still be happening, don't look at results*. Exposing a separate `overrunGrace` case to UI would imply we have authoritative live data, which we don't.

### Proposed rules (internal to resolver)

1. `now < startsAt` → `.upcoming`
2. `startsAt <= now < endsAt` → `.inProgress` (scheduled window)
3. `endsAt <= now < endsAt + gracePeriod` → `.inProgress` (grace window)
4. `now >= endsAt + gracePeriod` → `.finished`
5. Override: if the next chronological session has already started → `.finished` (strongest available signal)

Rule 5 matters because if the next session is running, the previous one must be over for our purposes regardless of grace window.

### Why this is the right tradeoff

It is better to show a session as in progress for slightly too long than to show it as finished too early.

False positive `Finished` states are more harmful than conservative lag because the user explicitly wants to avoid being told something has ended when it has not.

## Recommended Implementation Shape

Keep this logic out of the widget and app views.

### Step 1: Add `gracePeriod` to `SessionKind`

Add alongside `defaultDuration` in `NoSpoilersCore/Sources/NoSpoilersCore/SessionKind.swift`:

```swift
public var gracePeriod: TimeInterval {
    switch self {
    case .freePractice1, .freePractice2, .freePractice3: return 30 * 60
    case .qualifying:       return 30 * 60
    case .sprintQualifying: return 25 * 60
    case .sprint:           return 25 * 60
    case .race:             return 90 * 60
    }
}
```

Grace values are defined here — not scattered in UI code.

### Step 2: Add `SessionStatus` and `SessionResolver` to `NoSpoilersCore`

New file `NoSpoilersCore/Sources/NoSpoilersCore/SessionStatus.swift`:

```swift
public enum SessionStatus {
    case upcoming
    case inProgress
    case finished
}

public struct SessionResolver {
    public static func status(
        for session: Session,
        at now: Date,
        nextSession: Session? = nil
    ) -> SessionStatus {
        if now < session.startsAt { return .upcoming }
        if let next = nextSession, now >= next.startsAt { return .finished }
        let graceEnd = session.endsAt + session.kind.gracePeriod
        if now < graceEnd { return .inProgress }
        return .finished
    }
}
```

This boundary owns:

- the grace-window policy
- the transition rules
- the canonical definition of "current" versus "finished"

### Step 3: Replace direct `endsAt` comparisons at all call sites

Update every open-coded `session.endsAt < now` / `session.startsAt <= now && now < session.endsAt` check to use `SessionResolver.status(for:at:nextSession:)` instead.

Call sites:

- `NoSpoilersCore/Sources/NoSpoilersCore/ScheduleStore.swift` — `menuBarLabel`
- `NoSpoilers/NoSpoilersMac/ContentView.swift` — `sessionRow`, `statusBadge`, current weekend selection
- `NoSpoilers/NoSpoilersWidget/NoSpoilersWidget.swift` — `sessionState(for:at:)`, `makeEntry(at:)`, `nextReloadDate(after:)`

### Step 4: Keep presentation separate from resolution

UI surfaces map `SessionStatus` to their own labels:

| Status | macOS popover badge | Menu bar | Widget |
|--------|--------------------|-----------| -------|
| `.upcoming` | countdown pill | countdown | countdown |
| `.inProgress` | "In Progress" (accent color) | session name | "Now" |
| `.finished` | "Finished Xh ago" (green) | next session countdown | "Finished" |

"In Progress" replaces the hard "LIVE" red badge — we don't have authoritative live data, so we shouldn't imply it.

## Grace Window Values

Defined in `SessionKind.gracePeriod` (see Step 1 above). Initial values:

| Kind | Grace |
|------|-------|
| freePractice1/2/3 | 30 min |
| qualifying | 30 min |
| sprintQualifying | 25 min |
| sprint | 25 min |
| race | 90 min |

These are intentionally conservative. Do not scatter them across UI code.

## Important Edge Cases

### Gap before next session

A long gap before the next scheduled session must not force the current session to `finished` immediately after its default duration expires.

### Reload timing

The widget currently reloads at `currentSession.endsAt`.

Replace with `min(currentSession.endsAt + currentSession.kind.gracePeriod, nextSession?.startsAt ?? .distantFuture)`. The widget must stay in `inProgress` state until the resolver returns `.finished`, not until the scheduled end passes.

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
- Widget, menu bar, and macOS popover all use `SessionResolver` — no open-coded `endsAt` comparisons remain
- The three-state model (`upcoming` / `inProgress` / `finished`) is the only public contract; grace logic is internal
- The current weekend remains visible while a session is plausibly still running
- The menu bar shows the current session name (not the next session countdown) while a session is within its grace window
- Widget reload uses `endsAt + gracePeriod`, not bare `endsAt`

## Verification Plan

1. Unit tests in `NoSpoilersCore` for `SessionResolver`:
   - `.upcoming` before `startsAt`
   - `.inProgress` during scheduled window (`startsAt` to `endsAt`)
   - `.inProgress` during grace window (`endsAt` to `endsAt + gracePeriod`)
   - `.finished` after grace window expires
   - `.finished` when next session has started (override rule)

2. Manual spot checks with synthetic timestamps:
   - race session 1 minute after scheduled end → "In Progress", not "Finished"
   - race session 91 minutes after scheduled end → "Finished"
   - menu bar keeps session name during grace, not countdown to next session
   - widget does not advance to next session at the synthetic `endsAt` boundary

3. Real weekend validation:
   - confirm the app does not prematurely flip to finished if a session runs long

## Open Question

If a future data source provides authoritative live status or actual finish times, this task should extend the shared resolver to consume that source rather than replacing the UI contracts again.

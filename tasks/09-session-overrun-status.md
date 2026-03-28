# Task 09: Session Overrun Status Handling

**Status:** Phase 1 complete — Phase 2 (OpenF1 confirmation) TODO
**Depends on:** None
**Effort:** Phase 2 ~2-3 hours
**Priority:** High for real race-weekend correctness

## Goal

Prevent the app from showing an F1 session as finished when the real-world event is still running past its scheduled duration, and — once a session has actually ended — confirm that end authoritatively so the app does not stay in "In Progress" too long.

The product requirement is conservative: if we do not know that a session has definitely ended, we should not show `Finished`.

## Problem Summary

The schedule feed (`sportstimes/f1` on GitHub) provides only session start times. It has no live status and no confirmed end times. `Session.endsAt` is a synthetic value: `startsAt + kind.defaultDuration`.

F1 sessions routinely overrun — races can extend well past two hours due to safety cars, red flags, or weather. Qualifying sessions can run long due to stoppages.

## Data Sources Investigated

### Current feed: sportstimes/f1

Static community-maintained JSON calendar. Start times only. No live status. No actual end times. This is not going to change.

### OpenF1 `/v1/sessions`

Has a `date_end` field, but it is the **scheduled** end time, not actual. Sessions are updated at midnight UTC only. Useless for real-time end detection.

```json
{
  "date_start": "2025-12-07T13:00:00+00:00",
  "date_end":   "2025-12-07T15:00:00+00:00"   ← scheduled only
}
```

For the Abu Dhabi 2025 race, the `date_end` was 15:00 but the race actually finished at 14:29 — the `date_end` was never updated.

### OpenF1 `/v1/race_control?category=SessionStatus`

This is the **authoritative source**. It has `SESSION STARTED` and `SESSION FINISHED` messages with exact timestamps, e.g.:

```json
[
  { "date": "2025-12-07T13:03:27Z", "message": "SESSION STARTED"  },
  { "date": "2025-12-07T14:29:35Z", "message": "SESSION FINISHED" }
]
```

This endpoint works for every session type. Qualifying produces per-phase messages (qualifying_phase 1/2/3). Races produce a single SESSION FINISHED.

**Limitation**: live data (session in progress + 30 min after actual end) requires a paid subscription (€9.90/mo). After 30 minutes the data becomes historical and is free, no auth required.

## Implemented: Phase 1 — Conservative Grace Windows

The first phase is already shipped. It establishes a conservative floor that prevents premature "Finished" without any external API dependency.

### What was built

**`SessionStatus` enum** (`NoSpoilersCore/Sources/NoSpoilersCore/SessionStatus.swift`):

```swift
public enum SessionStatus {
    case upcoming
    case inProgress   // scheduled window OR within grace period
    case finished
}
```

**`SessionResolver`** — single shared boundary, used by all surfaces:

```swift
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

**`SessionKind.gracePeriod`** — conservative per-kind windows:

| Kind | Grace |
|------|-------|
| freePractice1/2/3 | 30 min |
| qualifying | 30 min |
| sprintQualifying | 25 min |
| sprint | 25 min |
| race | 90 min |

All direct `endsAt` comparisons in `ScheduleStore`, `ContentView`, and `NoSpoilersWidget` were replaced with `SessionResolver` calls. Widget reload timing was updated to `endsAt + gracePeriod`.

### What Phase 1 does not solve

Phase 1 is conservative in both directions:
- **Overruns**: session stays "In Progress" through the grace window — correct behaviour
- **Early finishes**: session also stays "In Progress" through the full grace window after actual end — the app lags reality by up to the full grace period (90 min for races)

The Abu Dhabi 2025 race is a good example: it finished 30 min early. With Phase 1, the app would stay "In Progress" for 90 min after the scheduled end — meaning ~120 min after the race actually finished. That is safe (no spoilers) but not precise.

## Recommended: Phase 2 — OpenF1 Confirmation (Free Tier)

Use the `race_control` endpoint to confirm actual session end time once the 30-min historical window expires. This tightens the lag from "up to full grace period" to "at most 30 minutes after actual end".

### How it works

1. When a session enters `inProgress` state and passes `endsAt`, start polling:
   ```
   GET https://api.openf1.org/v1/race_control?session_key={key}&category=SessionStatus&message=SESSION FINISHED
   ```
2. The `SESSION FINISHED` record becomes available on the free tier approximately 30 minutes after the actual end of the session.
3. When the record appears, cache its `date` as the confirmed end time.
4. Pass the confirmed end time into `SessionResolver` so it can transition to `.finished` immediately, bypassing the remaining grace window.

### Matching OpenF1 sessions to calendar sessions

OpenF1 uses its own `session_key`. To look up the key for the current session:

```
GET https://api.openf1.org/v1/sessions?session_key=latest
```

During and shortly after an active session, `latest` returns the correct session. Cache the `session_key` and `meeting_key` when the session transitions to `inProgress`.

Alternatively, look up by year + session type + date range:

```
GET https://api.openf1.org/v1/sessions?year=2026&session_type=Race&date_start>=2026-03-28
```

### Rate limits

Free tier: 3 req/s, 30 req/min. Polling every 2 minutes is well within limits.

### Where the confirmation lives

`SessionResolver` should accept an optional confirmed end date:

```swift
public static func status(
    for session: Session,
    at now: Date,
    nextSession: Session? = nil,
    confirmedEndAt: Date? = nil        // from OpenF1 if available
) -> SessionStatus {
    if now < session.startsAt { return .upcoming }
    if let next = nextSession, now >= next.startsAt { return .finished }
    let effectiveEnd = confirmedEndAt ?? (session.endsAt + session.kind.gracePeriod)
    if now < effectiveEnd { return .inProgress }
    return .finished
}
```

When `confirmedEndAt` is set, the grace window is bypassed entirely — the confirmed timestamp is the definitive end.

### Where the polling lives

A new `SessionEndConfirmer` (or similar) in `NoSpoilersCore`:
- Owns the OpenF1 polling loop
- Publishes `confirmedEndAt: Date?` for the current session
- Only active while a session is in the overrun window (`endsAt < now < endsAt + gracePeriod`)
- Caches results so a confirmed end persists across app restarts

`ScheduleStore` or the app layer picks up `confirmedEndAt` and threads it through `SessionResolver`.

### Failure mode

If OpenF1 is unreachable or returns an empty result, the resolver falls back to the grace window as normal. Phase 1 is the safety net; Phase 2 is precision on top.

### Cost

Zero. All polling happens after the 30-min historical window, which is the free tier. No subscription needed.

The only scenario that would require a paid subscription is if we wanted to detect the session end in real-time (i.e., within 30 minutes of it happening). For this app's use case — not showing "Finished" too early — the 30-min delay is perfectly acceptable. A 30-min lag in confirming an overrun is much better than the current 90-min grace window.

## Implementation Steps for Phase 2

### 1. Extend `SessionResolver` to accept `confirmedEndAt`

In `NoSpoilersCore/Sources/NoSpoilersCore/SessionStatus.swift`, add the optional parameter as shown above. All existing call sites pass `nil` by default — no breaking changes.

### 2. Add `OpenF1Client` to `NoSpoilersCore`

New file `NoSpoilersCore/Sources/NoSpoilersCore/OpenF1Client.swift`. Responsibilities:
- Look up the OpenF1 `session_key` for a given calendar session (by year, type, and date)
- Fetch `race_control?category=SessionStatus&message=SESSION FINISHED` for a session key
- Return the confirmed end `Date?` — `nil` if not yet available

Keep it stateless. Caching is the caller's responsibility.

### 3. Add `SessionEndConfirmer` to `NoSpoilersCore`

New `@MainActor` class, `ObservableObject`. Publishes `confirmedEndAt: [Session.ID: Date]`. Internally:
- Watches for sessions that are in the overrun window (`endsAt < now < endsAt + gracePeriod`)
- For each such session: polls `OpenF1Client` on a 2-minute timer
- When confirmed, stores the date and cancels the timer for that session
- Persists confirmed dates to `UserDefaults` / `AppGroup` so they survive restarts

### 4. Wire `SessionEndConfirmer` into `ScheduleStore`

Hold a `SessionEndConfirmer` instance in `ScheduleStore` (or at the app level alongside it). When calling `SessionResolver.status(for:at:nextSession:)`, look up `confirmedEndAt` for the session and pass it through.

### 5. No UI changes required

The resolver already produces `.finished` at the right moment. UI surfaces are unaffected.

## Critical Files

| Path | Action |
|------|--------|
| `NoSpoilersCore/Sources/NoSpoilersCore/SessionStatus.swift` | Add `confirmedEndAt` parameter to `SessionResolver` |
| `NoSpoilersCore/Sources/NoSpoilersCore/OpenF1Client.swift` | New — OpenF1 session lookup + race_control fetch |
| `NoSpoilersCore/Sources/NoSpoilersCore/SessionEndConfirmer.swift` | New — polling loop, publishes confirmed end dates |
| `NoSpoilersCore/Sources/NoSpoilersCore/ScheduleStore.swift` | Wire `confirmedEndAt` through to `SessionResolver` |

## Acceptance Criteria (Phase 2)

- When a session ends early (before grace period expires), the app transitions to `.finished` within 30 minutes of actual end, not after the full grace window
- When OpenF1 is unreachable, the app falls back to Phase 1 grace windows — no regression
- Confirmed end dates persist across app restarts
- Widget reload timing accounts for the confirmed end date when available
- No UI surface changes — only the resolver's effective end time changes

## Verification Plan

1. Unit tests for updated `SessionResolver`:
   - With `confirmedEndAt` before grace end → `.finished` immediately
   - Without `confirmedEndAt` → falls back to grace window (existing tests unchanged)

2. Unit tests for `OpenF1Client`:
   - Parses `SESSION FINISHED` correctly from a fixture response
   - Returns `nil` when response is empty (session not yet in historical window)

3. Integration smoke test: query the Abu Dhabi 2025 race (`session_key=9839`) — confirmed end should be `2025-12-07T14:29:35Z`.

4. Manual end-to-end: set system clock to just after a race's scheduled end, verify the app stays "In Progress", waits ~30 min, then confirms and flips.

## OpenF1 API Reference

```
Base URL: https://api.openf1.org/v1

Sessions (schedule match):
  GET /sessions?session_key=latest
  GET /sessions?year=2026&session_type=Race

Session status events:
  GET /race_control?session_key={key}&category=SessionStatus

Filter to finish only:
  GET /race_control?session_key={key}&category=SessionStatus&message=SESSION FINISHED

No authentication required. Free tier: 3 req/s, 30 req/min.
Live window: 30 min before session start to 30 min after actual end.
Outside live window: free, no auth.
```

# Task 07: Cancelled Race Display

**Status:** TODO
**Depends on:** Task 04 (WidgetKit timeline working)
**Effort:** ~2 hours
**Priority:** Low — deferred from v1

## Background

The 2026 F1 season had Bahrain (Round 4, April 10-12) and Saudi Arabia (Round 5, April 17-19) cancelled before they were due to run. The user raised this during planning: a cancelled race should appear in the widget as "Cancelled", not disappear silently.

## How f1calendar Handles Cancellations

Two-phase lifecycle (observed from commit history of `_db/f1/2026.json`):

1. **Mark phase** (~12 days): Race object gains `"canceled": true`. Session timestamps remain present.
   ```json
   {
     "name": "Bahrain",
     "round": 4,
     "canceled": true,
     "sessions": {
       "fp1": "2026-04-10T11:30:00Z",
       ...
     }
   }
   ```

2. **Remove phase**: Race is deleted from the feed entirely. Remaining rounds are renumbered. No trace in the feed after this point.

Observed timeline: marked 2026-03-14, removed 2026-03-26 (12 days).

## The UX Problem

During and after the mark phase, the widget should show:
```
Bahrain Grand Prix — Cancelled
Saudi Arabian Grand Prix — Cancelled
```

Rather than skipping those weekends silently or jumping from Round 3 (Japan) directly to the next active race. The user wants to see where the gap is in the season.

After the remove phase, the cancelled race dates pass silently — the feed no longer knows they existed.

## Why v1 Is Fine Without This

Swift's `Codable` ignores unknown keys by default. The `canceled: true` field is silently dropped during decoding today. No crashes. The cancelled races are removed from the feed within ~12 days of being marked, and the round numbers are renumbered — the "next race" logic naturally shows the correct next active race.

For 2026, both cancellations happened before Round 3 (Japan, March 27-29), so users running the app for the first time will see the correct post-removal 22-race calendar.

## Implementation Plan (when ready)

### 1. Decoder: add `isCancelled` to `RaceWeekend`

```swift
struct RaceWeekend: Codable {
    let round: Int
    let name: String
    let location: String
    let sessions: [SessionKind: Date]
    let isCancelled: Bool

    enum CodingKeys: String, CodingKey {
        case round, name, location, sessions
        case isCancelled = "canceled"  // American spelling in the feed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        round = try container.decode(Int.self, forKey: .round)
        name = try container.decode(String.self, forKey: .name)
        location = try container.decode(String.self, forKey: .location)
        sessions = try container.decode([String: Date].self, forKey: .sessions)
            .compactMapKeys { SessionKind(rawValue: $0) }
        isCancelled = try container.decodeIfPresent(Bool.self, forKey: .isCancelled) ?? false
    }
}
```

### 2. Cache persistence: freeze cancelled state

Once a `RaceWeekend` with `isCancelled = true` is written to the cache, keep it there even if the feed later drops it. Concretely: when merging a new fetch into the cache, if the feed removes a round that the cache knew as `isCancelled = true`, preserve the cancelled entry until its `gp` session date passes.

```swift
func merge(fetched: [RaceWeekend], into cached: [RaceWeekend]) -> [RaceWeekend] {
    let now = Date.now
    let fetchedRounds = Set(fetched.map(\.round))
    // Keep cancelled entries from cache that the feed has since removed,
    // as long as their GP date hasn't passed yet
    let cancelledGhosts = cached.filter { weekend in
        weekend.isCancelled &&
        !fetchedRounds.contains(weekend.round) &&
        weekend.sessions[.race].map { $0 > now } ?? false
    }
    return (fetched + cancelledGhosts).sorted { $0.round < $1.round }
}
```

### 3. SessionState: add `.cancelled` case

```swift
enum SessionState {
    case watchable
    case live
    case upcoming(countdown: String)
    case scheduled(date: String)
    case offSeason(daysUntil: String)
    case cancelled                      // new
}
```

### 4. Widget view: render cancelled races

When `isCancelled == true`, display each session as `.cancelled` state, and show the race weekend name with a "Cancelled" label instead of a countdown.

```
Bahrain Grand Prix
Cancelled
```

In `.systemSmall`, the widget label shows the next active (non-cancelled) race if the upcoming round is cancelled.

### 5. ScheduleStore: "next race" skips cancelled

The `menuBarLabel` on `ScheduleStore` and the "next race" off-season logic must skip `isCancelled == true` weekends when computing countdowns. Show cancelled races in the list, but don't count them for "race in X days."

## Edge Cases

- Feed removes a cancelled race before the cache syncs — handled by ghost preservation above
- All remaining races in the season are cancelled — fall through to off-season state
- `canceled: true` race with no sessions object — decode defensively, treat as empty sessions

## Acceptance Criteria

- `RaceWeekend.isCancelled` decodes `canceled: true` correctly; defaults to `false` when absent
- Cancelled race appears in widget as "Cancelled" for its scheduled weekend dates
- "Next race" countdown skips cancelled rounds
- Ghost cache preservation: a cancelled race stays visible until its GP date passes, even after feed removes it
- After GP date: cancelled entry expires from view naturally

# Task 04: WidgetKit Timeline Provider

**Status:** TODO
**Depends on:** Task 03 (ScheduleStore + cache working)
**Effort:** ~3 hours

## Goal

Implement the iOS WidgetKit `TimelineProvider` that generates the race weekend timeline. The widget shows the full weekend — past sessions (watchable) and upcoming sessions (countdown) — updating itself without user interaction.

## Widget Display Logic

A session's state is determined at render time:

| Condition | Display |
|---|---|
| `session.endsAt < now` | "[SessionName] — watchable" |
| `session.startsAt <= now <= session.endsAt` | "[SessionName] — now" |
| `session.startsAt > now` | "[SessionName] in Xh Ym" |

No result data is displayed. The "watchable" label means "this has aired — you can watch it now." Nothing more.

## Timeline Strategy

```swift
struct NoSpoilersTimelineProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<NoSpoilersEntry>) -> Void)
}
```

**Entry generation:**
- Current race day: generate one entry per minute for the current session window
- Other days in the active weekend: one entry per hour at session boundaries
- Future weekends (>7 days): one entry per day
- Off-season (no weekend within 7 days): one entry showing "next race in X days"
- Zero-data state (no cache, no bundle): one entry showing "Schedule unavailable — open app to refresh"

**Reload policy:**
```swift
let reloadDate = [
    currentSession?.endsAt,
    nextSession?.startsAt
].compactMap { $0 }.min() ?? nextWeekendStart
return Timeline(entries: entries, policy: .after(reloadDate))
```

Reload fires at whichever comes first: current session ends (flip to "watchable") or next session starts (new countdown). This is load-bearing — using only `nextSession.startsAt` would cause the "watchable" flip to fire late.

**WidgetKit refresh budget:** ~40-70 reloads/day system-wide across all widgets on the device. The reload policy above produces ~5-8 reloads per race day. This is well within budget.

## Widget Views

```swift
struct NoSpoilersWidgetEntryView: View {
    let entry: NoSpoilersEntry
    // Shows: weekend name + session list with state labels
    // Sizes: .systemSmall (next session only), .systemMedium (full weekend)
}
```

Supported sizes: `.systemSmall`, `.systemMedium`. Lock screen is out of scope for v1.

## Off-Season State

When no race weekend is active or within 7 days:

```
Off-season
Next race: [Grand Prix Name]
in [N] days
```

## Entry Model

```swift
struct NoSpoilersEntry: TimelineEntry {
    let date: Date
    let weekend: RaceWeekend?   // nil = off-season or no data
    let sessions: [SessionViewModel]
    let offSeasonNextRace: SessionViewModel?
}

struct SessionViewModel {
    let name: String            // "Free Practice 1", "Qualifying", "Race", etc.
    let state: SessionState
}

enum SessionState {
    case watchable
    case live
    case upcoming(countdown: String)  // "in 4h 23m"
    case scheduled(date: String)      // "Sat 14:00"
    case offSeason(daysUntil: String) // "in 12 days"
}
```

## Acceptance Criteria

- Widget renders correctly for: active session, upcoming session, past session, off-season, no-data
- `TimelineReloadPolicy` fires at `min(currentSession.endsAt, nextSession.startsAt)`
- "Watchable" state flips at `endsAt`, not `startsAt`
- No result data in any `SessionViewModel` field — verified by inspection
- Widget previews work in Xcode canvas for all states

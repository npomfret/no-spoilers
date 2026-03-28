# Task 03: Schedule Fetcher + Cache

**Status:** TODO
**Depends on:** Task 02 (project structure exists)
**Effort:** ~3 hours

## Goal

Implement the schedule fetch, decode, and cache layer in `NoSpoilersCore`. The iOS app writes to the App Group shared container; the widget extension reads from it. The macOS app uses its own container.

## Spoiler Contract

The fetcher touches only schedule data. The schema contract:

> The parsed JSON must contain no `results`, `winner`, `position`, `points`, `laps`, or `grid` keys at any nesting level.

If the decoder encounters unexpected keys that look like result data, it must ignore them — Swift's `Codable` ignores unknown keys by default. The domain model enforces the boundary: no result fields exist anywhere in app code or cache.

## Feed

```
https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/2026.json
```

Bundled fallback: a copy of this JSON file checked into the repo at `NoSpoilersCore/Resources/2026.json`. Loaded via `Bundle.module`.

## Components to Build

### `ScheduleFetcher` (in NoSpoilersCore)

```swift
actor ScheduleFetcher {
    func fetch() async throws -> [RaceWeekend]
}
```

- Fetches the f1calendar.com feed
- Decodes using `JSONDecoder` with `.iso8601` date strategy (verify date format in task 01)
- Returns `[RaceWeekend]` sorted by date
- On failure, throws — caller decides whether to fall back to cache or bundle

### `ScheduleCache` (in NoSpoilersCore)

```swift
struct ScheduleCache {
    // iOS: reads/writes to App Group shared container
    // macOS: reads/writes to app container
    func save(_ weekends: [RaceWeekend], for appGroupID: String?) throws
    func load(for appGroupID: String?) throws -> [RaceWeekend]
    func loadBundled() throws -> [RaceWeekend]
}
```

Storage: write `[RaceWeekend]` as JSON to `containerURL/schedule-cache.json`. Use `UserDefaults(suiteName: appGroupID)` as an alternative for small payloads.

### `ScheduleStore` (in NoSpoilersCore — main entry point)

```swift
@MainActor
class ScheduleStore: ObservableObject {
    @Published var weekends: [RaceWeekend] = []

    func refresh() async
    // 1. Try fetch
    // 2. On failure, load from cache
    // 3. On cache miss, load from bundle
    // Never returns empty if bundle is present
}
```

## Cache Policy

- Cache valid for 24 hours
- Widget extension: read from cache only, never fetch
- App: fetch on launch, write to cache, reload WidgetKit timelines via `WidgetCenter.shared.reloadAllTimelines()`
- If cache is stale and fetch fails: use stale cache (better than bundle)
- If no cache: use bundle

## Bundled JSON

Check in `NoSpoilersCore/Resources/2026.json` (copy of the verified feed). This is the offline guarantee — the widget never shows a blank state even on first launch with no network.

Update this file manually when F1 adds or reschedules events mid-season.

## Acceptance Criteria

- `ScheduleFetcher.fetch()` returns correct `[RaceWeekend]` for the current season
- `ScheduleCache` round-trips data correctly via App Group container (verify with a unit test)
- `ScheduleStore` falls back to bundle when fetch fails and cache is empty
- No result fields in any decoded type — enforced by the model, not by filtering

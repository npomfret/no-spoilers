# No Spoilers

A spoiler-safe F1 race weekend widget for iPhone and macOS.

Shows the full race weekend timeline — past sessions (watchable now) and upcoming sessions (countdown) — with a hard guarantee that race results never appear. Not hidden by default. Never requested. Never in the data model.

## The Problem

F1 fans who watch on replay need to know when sessions happen. Every existing source — Google, the F1 app, sports sites — shows race results the moment you look for schedule information. There is no safe place to check.

## The Solution

A native widget on your iPhone home screen and macOS menubar that shows:

- Sessions that have ended: ready to watch
- Current or next session: countdown in local time
- The rest of the weekend: at a glance

Nothing else. No standings. No results. No driver news. Opening this app is always safe.

## Architecture

The spoiler guarantee is architectural, not a settings toggle. The app's domain model has no result fields — they don't exist, they're not hidden. The data source (f1calendar.com) is schedule-only by design.

```
no-spoilers/
├── NoSpoilers/             # Shared Swift Package (business logic)
│   ├── Sources/
│   │   └── NoSpoilersCore/ # Session model, feed fetcher, cache
│   └── Package.swift
├── NoSpoilersApp/          # iOS app target
├── NoSpoilersWidget/       # iOS widget extension target
├── NoSpoilersMac/          # macOS app target (MenuBarExtra)
├── research/               # Reference material
│   ├── claude-code-research/
│   └── example-project/    # CodexBar — architectural reference
└── tasks/                  # Implementation task files
```

### Targets

| Target | Platform | Purpose |
|--------|----------|---------|
| `NoSpoilersApp` | iOS 17+ | Host app, schedule fetch, App Group cache write |
| `NoSpoilersWidget` | iOS 17+ | WidgetKit extension, reads App Group cache |
| `NoSpoilersMac` | macOS 14+ | MenuBarExtra + popover, independent fetch |

### Data Flow

1. iOS app fetches `https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/2026.json` on launch
2. Decoded `[Session]` written to App Group shared container
3. Widget extension reads from shared container, generates WidgetKit timeline
4. Timeline reloads at `min(nextSession.startsAt, currentSession.endsAt)` — whichever comes first
5. macOS app fetches independently, caches in its own container

Fallback: a bundled copy of the season JSON ships inside the app binary. If the network fetch fails, the bundled JSON ensures the widget never shows a blank state.

### Domain Model

```swift
struct Session: Codable, Identifiable, Hashable {
    var id: String { "\(round)-\(kind.rawValue)" }
    let round: Int
    let grandPrixName: String
    let circuitName: String
    let location: String
    let kind: SessionKind
    let startsAt: Date
    let endsAt: Date
    // No result fields. Not optional. Not ignored. They don't exist.
}
```

A session is "watchable" when `endsAt < Date.now`.

## Platform Requirements

- iOS 17+ (WidgetKit timeline features)
- macOS 14+ (MenuBarExtra API)

## Data Source

**f1calendar.com** — community-maintained, schedule-only JSON feed. Ergast API is deprecated as of late 2024; do not use it.

Feed URL: `https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/2026.json`

The feed schema has been verified to contain no result data. See `tasks/01-verify-feed-schema.md`.

## Development

Open in Xcode. No dependencies beyond the Swift standard library and Apple frameworks.

Required entitlements (iOS):
- `com.apple.security.network.client`
- `com.apple.security.application-groups` (shared between app and widget extension)

## Design Document

Full design rationale, architecture decisions, and implementation notes:
`~/.gstack/projects/no-spoilers/nickpomfret-main-design-20260328-093516.md`

## Tasks

See `tasks/` for implementation task files.

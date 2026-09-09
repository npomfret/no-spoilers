# No Spoilers

**[nospoilers.app](https://npomfret.github.io/no-spoilers)** — a spoiler-free Grand Prix weekend widget for iPhone and macOS.

[Privacy Policy](https://npomfret.github.io/no-spoilers/privacy.html)

Shows the full race weekend timeline — past sessions (watchable now) and upcoming sessions (countdown) — with a hard guarantee that race results never appear. Not hidden by default. Never requested. Never in the data model.

## The Problem

Fans who watch on replay need to know when sessions happen. Every existing source — Google, the official series app, sports sites — shows race results the moment you look for schedule information. There is no safe place to check.

## The Solution

A native widget on your iPhone Home Screen and macOS menubar that shows:

- Sessions that have ended: ready to watch
- Current or next session: countdown in local time
- The rest of the weekend: at a glance

Nothing else. No standings. No results. No driver news. Opening this app is always safe.

## Architecture

The spoiler guarantee is architectural, not a settings toggle. The app's domain model has no result fields — they don't exist, they're not hidden. The data source (f1calendar.com) is schedule-only by design.

```
no-spoilers/
├── NoSpoilersCore/             # Shared Swift package (business logic)
│   ├── Package.swift
│   ├── Sources/NoSpoilersCore/ # Session model, feed fetcher, cache, shared views
│   └── Tests/NoSpoilersCoreTests/
├── NoSpoilers/                 # Xcode project — all three app targets live here
│   ├── NoSpoilers.xcodeproj
│   ├── NoSpoilers/             # iOS app target (NoSpoilersApp)
│   ├── NoSpoilersWidget/       # iOS widget extension (NoSpoilersWidgetExtension)
│   ├── NoSpoilersMac/          # macOS app target (MenuBarExtra)
├── scripts/                    # Build, release and App Store Connect tooling
├── docs/                       # GitHub Pages site, brand, and contributor guides
├── research/                   # Reference material
│   ├── claude-code-research/
│   └── example-project/        # CodexBar — architectural reference
└── tasks/                      # Implementation task files
```

The package is the shared code and knows nothing about the apps; the Xcode project holds the three
targets and depends on it. The target and the directory are not always spelled the same — the iOS
app target is `NoSpoilersApp` and lives in `NoSpoilers/NoSpoilers/`.

### Targets

| Target | Platform | Purpose |
|--------|----------|---------|
| `NoSpoilersApp` | iOS 26.2+ | Host app, schedule fetch, App Group cache write |
| `NoSpoilersWidgetExtension` | iOS 26.2+ | WidgetKit extension, reads App Group cache |
| `NoSpoilersMac` | macOS 26.2+ | MenuBarExtra + popover, independent fetch |

### Data Flow

1. `ScheduleFetcher` reads the feed's `config.json` for `calendarOutputYear`, then fetches
   `<feed root>/<year>.json`. The year is never hard-coded and never taken from the clock; the feed
   says which season it is publishing, and that is the only signal that is actually about the data.
2. Decoded `[RaceWeekend]` is written to the App Group shared container by `ScheduleStore`
3. Widget extension reads from the shared container and builds a WidgetKit timeline
4. `TimelinePlanner` decides the entry dates and the `.after(_:)` reload date from the session
   boundaries ahead — it is a pure function of `now` so the arithmetic is testable
5. macOS app fetches independently through the same `ScheduleStore`, into its own container

There is no bundled copy of the season. If a refresh fails, `ScheduleStore` keeps whatever it has
already published, or loads the last successful fetch from the cache when it has nothing. A first
launch with no network shows the empty state rather than a guess.

### Domain Model

```swift
struct RaceWeekend: Codable, Identifiable, Hashable {   // what the feed decodes into
    let round: Int
    let name: String                                    // "Australian"
    let location: String
    let sessions: [SessionKind: Date]
    // No result fields. Not optional. Not ignored. They don't exist.
}

struct Session: Identifiable, Hashable {                // derived per session for the views
    var id: String { "\(round)-\(kind.rawValue)" }
    let round: Int
    let grandPrixName: String
    let location: String
    let kind: SessionKind
    let startsAt: Date
    var endsAt: Date { startsAt.addingTimeInterval(kind.defaultDuration) }
}
```

A session is "watchable" once it has ended. The scheduled end is `startsAt` plus the kind's default
duration; during the overrun grace window after that, `SessionEndConfirmer` asks OpenF1 whether the
session has actually finished and stores the confirmed end in the App Group, so a red-flagged race
is not called safe while it is still running.

## Platform Requirements

- iOS 26.2+
- macOS 26.2+

Both app targets set a deployment target of 26.2. The `NoSpoilersCore` package declares the lower
`.iOS(.v17)` / `.macOS(.v14)` floor it actually needs, which is why those numbers appear in
`Package.swift`; they are not what the shipped apps require.

## Data Source

**f1calendar.com** — community-maintained, schedule-only JSON feed. Ergast API is deprecated as of late 2024; do not use it.

Feed root: `https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/`. The season file is
`<calendarOutputYear>.json`, with the year read from `config.json` at the same root.

The feed schema has been verified to contain no result data.

**OpenF1** is the only other network source. It is queried for one thing — whether a session has
finished — and only during the grace window after a session's scheduled end. Nothing else from it
enters the model.

## Install

Both apps are on the App Store under one listing:
[apps.apple.com/gb/app/id6761343835](https://apps.apple.com/gb/app/id6761343835). The iPhone app
went live on 2026-09-02.

The macOS menu bar app is also on Homebrew:

```bash
brew install --cask npomfret/tap/no-spoilers
```

Updates via `brew upgrade`.

## Development

Open in Xcode. No dependencies beyond the Swift standard library and Apple frameworks.

Required entitlement (iOS app and widget extension):
- `com.apple.security.application-groups` — the shared container the widget reads

### Releasing

Four wrapper scripts handle distribution, all over the one engine `scripts/release.sh`. Each
suggests the next version, runs the Core tests as a gate, archives, and only then commits and pushes
the version bump — so a failed archive leaves no bump behind. Releases run on your machine, or on a
TeamCity agent by pressing `Publish`. An uploaded build reaches no tester until it is handed over:
locally with `scripts/testflight_distribute.py --apply`, or by pressing `TestFlight` on TeamCity,
which runs it for both platforms. See *TestFlight from TeamCity* in
`docs/guides/building.md`.

| Script | What it does |
|--------|-------------|
| `scripts/ship.sh` | All three channels in one run, version-locked (recommended) |
| `scripts/ship-homebrew.sh` | Homebrew / Developer ID only |
| `scripts/ship-appstore.sh` | Mac App Store only |
| `scripts/ship-ios.sh` | iOS App Store only |

The suggested version is one patch above the higher of the newest `vX.Y.Z` tag and the project's
`MARKETING_VERSION`. It needs both: opening a version train without shipping it moves the
project ahead of the tags, and a suggestion
based on tags alone would walk the project backwards, since `release.sh` sets `MARKETING_VERSION`
to whatever it is given.

**Release to both channels (normal flow):**

```bash
scripts/ship.sh
```

Bumps the version, archives once, then:
- Developer ID path: notarizes, staples, creates GitHub release, updates homebrew-tap
- App Store path: exports `.pkg`, uploads to App Store Connect

**Release to Homebrew only:**

```bash
scripts/ship-homebrew.sh
```

Requires the keychain profile `no-spoilers-notarytool` to be configured for notarization. To set it up:

```bash
xcrun notarytool store-credentials "no-spoilers-notarytool" \
  --apple-id YOUR_APPLE_ID \
  --team-id 6FZN56WC8G \
  --password APP_SPECIFIC_PASSWORD
```

**Release to App Store only:**

```bash
scripts/ship-appstore.sh
```

Reads the App Store Connect API key from `~/.appstoreconnect/private_keys/AuthKey_S394C74APG.p8`.
After upload, go to App Store Connect and submit for review.

**Credentials needed:**
- Notarization: keychain profile `no-spoilers-notarytool` (set up once via `xcrun notarytool store-credentials`)
- App Store upload: `~/.appstoreconnect/private_keys/AuthKey_S394C74APG.p8` (download once from App Store Connect → Users and Access → Integrations → API)

### Shipping an iOS build to TestFlight

Press `Publish` on TeamCity, or run `scripts/ship-ios.sh` locally. **The build then reaches no
tester until you hand it over.** That is a command rather than an automatic step, so that shipping
several times a day does not notify every tester several times a day.

```bash
# press Publish on ci.snowmonkey.co.uk, or: scripts/ship-ios.sh
scripts/testflight_distribute.py             # dry run — says what it would do
scripts/testflight_distribute.py --apply     # give the newest build to the internal group
```

`--apply` also writes the *What to Test* note from the commit that was built. It touches internal
groups only: `--group NAME` is needed for any other, and `--submit` sends an external build for Beta
App Review.

To see who can install what:

```bash
scripts/appstore_status.py                   # the TESTFLIGHT section
```

It reports both platforms, because a release ships both and a Mac build has to be handed over
separately. `testers can install build 12, 1 build behind build 13` is the ordinary state after a
ship, not a warning — the newest build sits undistributed until you run the command
above. Only "testers can install nothing" is reported as a problem.

The record holds two build-number bands: 1 to 125 from Xcode Cloud, which built this app until
2026-09-09, and 10000 up from `release.sh`, which builds it now. The number in the app's About
screen says which one shipped it.

Full detail, including why delivery is manual: the TestFlight section of `docs/guides/building.md`.

### Asking what App Store Connect holds

```bash
scripts/appstore_status.py          # add --json for the same thing as data
```

Prints both platforms side by side — macOS and iOS share one app record under
Universal Purchase, so their versions, listings, screenshots and review
submissions are separate and nothing in the UI shows them together. It reports
the current version and state for each, the listing text and screenshot counts
per locale, the App Review contact, and every review submission. `GET`s only,
using the same key as `scripts/ship-appstore.sh`; it exits 0 when nothing it can
see is waiting on you.

That is worth running before a release: on 2026-08-09 the macOS 1.0.21 was on
sale while the iOS 1.0.21 had been `REJECTED` since May, with its submission
still sitting in `UNRESOLVED_ISSUES`.

**Three things it cannot read, and prints as unknown rather than omitting.** App
Privacy — the data-collection questionnaire — has no App Store Connect API
endpoint at all. Price and availability need an App Manager key. And a
rejection's actual reasons live in Resolution Center. The API gives you states
and no prose: the version reads `REJECTED`, the submission `UNRESOLVED_ISSUES`,
and each item inside that submission `REJECTED` or `APPROVED` — what was refused,
never why. Resolution Center has no endpoint at all, so replying is browser work.

### Taking App Store screenshots

```bash
scripts/screenshots.py --device "iPhone 11 Pro Max" --expect 1242x2688 --widget-size large
```

Seeds a fixture into the App Group container, places the widget at the given size, boots the
simulator and captures to `tmp/screenshots/`. `--device` takes a name or a UDID and is repeatable;
a name matching two simulators is refused with the candidate UDIDs rather than guessed at, which is
the usual case once you have several runtimes installed. `--dry-run` prints the plan and stops.

Shooting against a fixture rather than the live
calendar is the whole point: the same command produces the same picture in March and in August,
where the real feed gives you the off-season state half the year.

The app is never launched during a run, and must not be — `ScheduleStore.refresh()` saves the
network result unconditionally, so opening the app to "make it pick up the data" is what destroys
the seeded data.

`--expect` fails a wrong device in seconds instead of at upload. **A blank or stale widget still
exits 0 with a valid PNG, so look at the picture before uploading it.** Full detail, including why
only `--install` clears a stored timeline: `docs/guides/building.md`.

## Design

`docs/guides/` is the design and architecture reference. `important-code.md` maps the control
plane and the files that define repo standards; `brand.md` is the cross-platform token spec
covering the three app targets and the GitHub Pages marketing surface; `building.md` is the
long-form account of every build, CI and delivery path; `testing.md` and `swift-patterns.md` hold
the conventions the code is expected to follow.

## Tasks

See `tasks/` for implementation task files.

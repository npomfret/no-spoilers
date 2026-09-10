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

Two deliveries, independent of each other: TestFlight on both platforms, and Homebrew. Full detail,
including why they were separated, is *Continuous delivery* in `docs/guides/building.md`.

**TestFlight: `scripts/submit_build.py`.** It refuses a dirty tree, a commit not on `origin/main` and
a version Apple has already approved; runs the Core tests; reserves the next build number as a
`build/N` tag; and then, for iOS and then macOS, archives, uploads, waits for Apple and hands that
exact build to the Internal testers with its *What to Test* note, reading both back.

```bash
scripts/submit_build.py --platform all                                # dry run: what would happen
scripts/submit_build.py --platform all --apply                        # do it
scripts/submit_build.py --platform macos --apply --archive-only       # prove signing; upload nothing
```

On TeamCity this is `Ship`, which runs `scripts/ci-publish.sh`: it asserts the agent can sign and
push, then runs the same thing against the revision `Verify` passed. Submitting for App Review is
still a person pressing Submit in App Store Connect.

A run that uploaded a build and could not finish delivering it names the recovery in its log and its
record — the same command, for that build only:

```bash
scripts/testflight_distribute.py --platform ios --build 10025 --apply
```

**Opening a new version: `scripts/open-version.sh X.Y.Z`.** Once Apple approves a version, its train
takes no more builds and `submit_build.py` refuses it, naming these two commands. The second commits
`open vX.Y.Z` and pushes it, and that commit is verified and shipped like any other; nothing that
archives changes the version.

```bash
scripts/tag_approved.py ios 1.1.4 --apply    # record which build users got
scripts/open-version.sh 1.1.5
```

**Homebrew: `scripts/ship-homebrew.sh`**, over `scripts/release.sh`. It releases the version the
commit holds — a notarized zip, a GitHub release and the cask — on its own cadence. Notarization uses
the keychain profile `no-spoilers-notarytool`. To set it up:

```bash
xcrun notarytool store-credentials "no-spoilers-notarytool" \
  --apple-id YOUR_APPLE_ID \
  --team-id 6FZN56WC8G \
  --password APP_SPECIFIC_PASSWORD
```

**Credentials needed:**
- App Store Connect keys in `~/.appstoreconnect/private_keys/`: `AuthKey_S394C74APG.p8`, the
  Developer key every read uses, and `AuthKey_ASC6H3SL2D.p8`, the App Manager key that signs,
  uploads and delivers (download once from App Store Connect → Users and Access → Integrations → API)
- Signing identities: *Apple Distribution* for both apps, *Mac Installer Distribution* ("3rd Party
  Mac Developer Installer" in the keychain) for the Mac App Store package, *Developer ID Application*
  for Homebrew. An agent needs the installer identity locally, because Apple refuses the App Manager
  key cloud-managed certificates
- Notarization: the keychain profile above, or the App Manager key on an agent

### Who can install what

```bash
scripts/appstore_status.py                   # the TESTFLIGHT section
```

It reports both platforms, because a release ships both and a Mac build is delivered separately.
`testers can install build 12, 1 build behind build 13` is the ordinary state while a build is
processing, not a warning. Only "testers can install nothing" is reported as a problem.

The record holds two build-number bands: 1 to 125 from Xcode Cloud, which built this app until
2026-09-09, and 10000 up since. The number in the app's About screen says which one shipped it.

### Asking what App Store Connect holds

```bash
scripts/appstore_status.py          # add --json for the same thing as data
```

Prints both platforms side by side — macOS and iOS share one app record under
Universal Purchase, so their versions, listings, screenshots and review
submissions are separate and nothing in the UI shows them together. It reports
the current version and state for each, the listing text and screenshot counts
per locale, the App Review contact, and every review submission. `GET`s only,
using the Developer key `S394C74APG`; it exits 0 when nothing it can
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

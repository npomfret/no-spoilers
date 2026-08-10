# No Spoilers

**[nospoilers.app](https://npomfret.github.io/no-spoilers)** — a spoiler-safe F1 race weekend widget for iPhone and macOS.

[Privacy Policy](https://npomfret.github.io/no-spoilers/privacy.html)

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
├── NoSpoilersCore/             # Shared Swift package (business logic)
│   ├── Package.swift
│   ├── Sources/NoSpoilersCore/ # Session model, feed fetcher, cache, shared views
│   └── Tests/NoSpoilersCoreTests/
├── NoSpoilers/                 # Xcode project — all three app targets live here
│   ├── NoSpoilers.xcodeproj
│   ├── NoSpoilers/             # iOS app target (NoSpoilersApp)
│   ├── NoSpoilersWidget/       # iOS widget extension (NoSpoilersWidgetExtension)
│   ├── NoSpoilersMac/          # macOS app target (MenuBarExtra)
│   └── ci_scripts/             # Xcode Cloud hooks — must sit beside the .xcodeproj
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

- iOS 26.2+
- macOS 26.2+

Both app targets set a deployment target of 26.2. The `NoSpoilersCore` package declares the lower
`.iOS(.v17)` / `.macOS(.v14)` floor it actually needs, which is why those numbers appear in
`Package.swift`; they are not what the shipped apps require.

## Data Source

**f1calendar.com** — community-maintained, schedule-only JSON feed. Ergast API is deprecated as of late 2024; do not use it.

Feed URL: `https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/2026.json`

The feed schema has been verified to contain no result data. See `tasks/01-verify-feed-schema.md`.

## Install

```bash
brew install --cask npomfret/tap/no-spoilers
```

This installs the macOS menu bar app. Updates via `brew upgrade`.

## Development

Open in Xcode. No dependencies beyond the Swift standard library and Apple frameworks.

Required entitlements (iOS):
- `com.apple.security.network.client`
- `com.apple.security.application-groups` (shared between app and widget extension)

### Releasing

Three wrapper scripts handle distribution. All auto-increment the version from the latest git tag, commit the bump, and push before building.

| Script | What it does |
|--------|-------------|
| `scripts/ship.sh` | Both channels in one run (recommended) |
| `scripts/ship-homebrew.sh` | Homebrew / Developer ID only |
| `scripts/ship-appstore.sh` | Mac App Store only |

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

A push to `main` builds the iOS app on Xcode Cloud and uploads it to TestFlight. **The build reaches
no tester until you hand it over.** That is a command rather than an automatic step, so that pushing
several times a day does not notify every tester several times a day.

```bash
git push                                     # Xcode Cloud archives and uploads
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

`testers can install build 12, 1 build behind build 13` is the ordinary state after a push, not a
warning — the newest build sits undistributed until you run the command above. Only "testers can
install nothing" is reported as a problem.

For a versioned App Store submission rather than a test build, use `scripts/ship-ios.sh`. The two
paths keep separate build-number bands — Xcode Cloud counts from 1, `release.sh` from 10000 — so
they cannot collide, and the build number in the app's About screen says which one shipped it.

Full detail, including why delivery is manual: `tasks/14-xcode-cloud-testflight.md`.

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
rejection's actual reasons live in Resolution Center; the API gives you the word
`REJECTED` and nothing else.

## Design Document

Full design rationale, architecture decisions, and implementation notes:
`~/.gstack/projects/no-spoilers/nickpomfret-main-design-20260328-093516.md`

Brand palette for the GitHub Pages docs and marketing surface:
`docs/brand.md`

## Tasks

See `tasks/` for implementation task files.

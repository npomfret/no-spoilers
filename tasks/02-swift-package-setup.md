# Task 02: Swift Package + Xcode Project Setup

**Status:** TODO
**Depends on:** Task 01 (feed schema verified)
**Effort:** ~2 hours

## Goal

Create the Xcode project with three targets sharing a single Swift Package for business logic. Wire up the App Group entitlement so the iOS app and widget extension can share the cached schedule data.

## Reference

Study `research/example-project/` (CodexBar) before starting:
- `Package.swift` — multi-target Swift Package structure
- `Sources/CodexBarCore/` — shared business logic pattern
- `Sources/CodexBar/` — macOS app, MenuBarExtra integration
- `Sources/CodexBarWidget/` — WidgetKit extension pattern

Do not copy code. Use it to understand the approved structural pattern.

## Xcode Project Structure

```
NoSpoilers.xcodeproj
├── NoSpoilersApp        (iOS, deployment target: iOS 17)
├── NoSpoilersWidget     (iOS widget extension, deployment target: iOS 17)
└── NoSpoilersMac        (macOS, deployment target: macOS 14)

NoSpoilersCore/          (Swift Package, local, shared by all targets)
└── Sources/NoSpoilersCore/
    ├── Session.swift
    ├── SessionKind.swift
    ├── RaceWeekend.swift
    └── ScheduleStore.swift  (protocol — platform implementations vary)
```

## Steps

1. **Create the Xcode project.** New project, multiplatform app template. Delete the default target structure — you'll replace it.

2. **Create three targets:**
   - `NoSpoilersApp` — iOS App, SwiftUI lifecycle
   - `NoSpoilersWidget` — Widget Extension
   - `NoSpoilersMac` — macOS App, SwiftUI lifecycle with `MenuBarExtra`

3. **Create the local Swift Package** `NoSpoilersCore` at the repo root. Add it to the Xcode project. All three targets depend on it.

4. **Implement the domain model** in `NoSpoilersCore` (schema confirmed in task 01):
   ```swift
   struct Session: Codable, Identifiable, Hashable {
       var id: String { "\(round)-\(kind.rawValue)" }
       let round: Int
       let grandPrixName: String   // constructed: "\(race.name) Grand Prix"
       let location: String
       let kind: SessionKind
       let startsAt: Date
       var endsAt: Date { startsAt.addingTimeInterval(kind.defaultDuration) }
   }

   enum SessionKind: String, Codable {
       case freePractice1 = "fp1"
       case freePractice2 = "fp2"
       case freePractice3 = "fp3"
       case qualifying = "qualifying"
       case sprintQualifying = "sprintQualifying"  // camelCase — matches feed key exactly
       case sprint = "sprint"
       case race = "gp"                            // feed key is "gp", not "race"

       var defaultDuration: TimeInterval {
           switch self {
           case .freePractice1, .freePractice2, .freePractice3: return 3600
           case .qualifying: return 3600
           case .sprintQualifying: return 2700
           case .sprint: return 1800
           case .race: return 7200
           }
       }
   }
   ```
   No result fields. `circuitName` is not in the feed — do not add it. If you find yourself adding a result field, stop.

5. **Configure App Group:**
   - In Xcode, add the `App Groups` capability to both `NoSpoilersApp` and `NoSpoilersWidget`
   - Use identifier: `group.com.[yourname].no-spoilers`
   - The macOS target does not need App Groups

6. **Verify the entitlements files** are generated correctly:
   - `NoSpoilersApp.entitlements` must contain `com.apple.security.application-groups`
   - `NoSpoilersWidget.entitlements` must contain `com.apple.security.application-groups`
   - `NoSpoilersMac.entitlements` must contain `com.apple.security.network.client` (App Sandbox)

7. **Smoke test:** Build all three targets. Fix any compile errors before continuing.

## Acceptance Criteria

- `xcodebuild -scheme NoSpoilersApp -destination 'platform=iOS Simulator,name=iPhone 16'` succeeds
- `xcodebuild -scheme NoSpoilersMac` succeeds
- App Group identifier is consistent across both iOS targets
- `Session` struct has no result fields

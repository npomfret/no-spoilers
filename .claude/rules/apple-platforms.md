---
description: Rules for Swift, Xcode, and Apple-platform application work.
paths:
  - "**/*.swift"
  - "Package.swift"
  - "**/*.xcodeproj/**/*"
  - "**/*.xcworkspace/**/*"
  - "**/*.plist"
  - "**/*.entitlements"
---

# Apple Platform Rules

- Confirm whether the active change lives in a Swift package, Xcode project, workspace, or generator-based setup before editing anything.
- Do not invent module names, schemes, destinations, products, bundle identifiers, capabilities, URL schemes, plist keys, or entitlement keys. Read the checked-in project files first.
- Read `docs/guides/swift-patterns.md` for substantial Swift or Apple-platform work.
- Load `pattern-governance-reference` and identify the nearest approved local pattern before editing.
- Reuse the existing architectural split. Do not mix new SwiftUI, UIKit, AppKit, or shared-core patterns into the same concern unless the task explicitly changes the standard.
- If the existing pattern is weak but clearly the repo standard, refactor that shared boundary instead of adding a second approach.
- Prefer shared reusable boundaries for domain logic, state coordination, navigation helpers, and persistence access when the same concern appears more than once.
- Treat duplicate view models, service layers, helpers, and coordinator patterns as correctness issues when they solve the same problem.
- Keep shared business logic in plain Swift modules when the repo already does that; keep platform-specific lifecycle and UI behavior in the owning app target.
- Call out intentional platform divergence between macOS and iOS. Do not let drift happen silently.
- Prefer the repo's canonical verification path. If the project has not standardized wrappers yet, verify the real entry point first and then use the smallest meaningful `swift` or `xcodebuild` command for the touched scope.
- Current canonical wrappers are `scripts/verify-core-tests.sh`, `scripts/verify-mac-build.sh`, `scripts/verify-ios-build.sh`, and `scripts/verify-widget-build.sh`.
- Avoid hand-editing generated project artifacts if the repo uses a generator or managed workflow. Update the source-of-truth files instead.
- Simulator or device assumptions must be explicit. When a destination matters, name the exact scheme and destination rather than relying on defaults.
- Never hardcode a user-visible string in view or model code. Every displayed string must go through the target's `Strings.swift`. See `docs/guides/swift-patterns.md` for the full rule and the distinction between shared-core strings and target-private strings.

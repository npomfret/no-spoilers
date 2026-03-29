# Task 11: Converge iOS And Widgets On The macOS Popover Style

**Status:** Done
**Depends on:** Task 10, existing `NoSpoilersCore` shared state and asset resources
**Priority:** High

## Goal

Make the iOS app and `NoSpoilersWidget` surfaces use the same visual language as the macOS popover:

- warm ivory/blush atmospheric background
- soft elevated cards
- F1 wordmark plus flag-led weekend header
- round pills and compact status chips
- session rows with the same accent-bar treatment

## Approved Pattern

The approved visual source of truth is the macOS popover in `NoSpoilersMac/ContentView.swift`.

The implementation should converge shared styling into `NoSpoilersCore` rather than duplicating layout chrome across iOS and WidgetKit.

## Plan

1. Add shared SwiftUI presentation primitives to `NoSpoilersCore` for:
   - background
   - card surface
   - wordmark
   - round pill
   - session status badge
2. Refactor the iOS app screen to use those primitives and match the desktop popover hierarchy more closely.
3. Refactor widget families to use the same card/background/header/session-row language, adapted to family constraints.
4. Verify the package plus Xcode targets at the smallest meaningful scope.

## Verification

1. `swift test`
   Working directory: `NoSpoilersCore`
   Result: passed
   Note: existing warning remains in `SessionEndConfirmer` about `storageKey` actor isolation under Swift 6 mode.

2. `xcodebuild -project NoSpoilers/NoSpoilers.xcodeproj -scheme NoSpoilersApp -destination 'generic/platform=iOS' -derivedDataPath /tmp/no-spoilers-ios CODE_SIGNING_ALLOWED=NO build`
   Result: passed

3. `xcodebuild -project NoSpoilers/NoSpoilers.xcodeproj -scheme NoSpoilersWidgetExtension -destination 'generic/platform=iOS' -derivedDataPath /tmp/no-spoilers-widget CODE_SIGNING_ALLOWED=NO build`
   Result: passed

4. `xcodebuild -project NoSpoilers/NoSpoilers.xcodeproj -scheme NoSpoilersMac -destination 'generic/platform=macOS' -derivedDataPath /tmp/no-spoilers-mac CODE_SIGNING_ALLOWED=NO build`
   Result: passed

# Task 12: Tighten Widget Freshness And Chrome

**Status:** Done
**Depends on:** Task 11 shared chrome, existing WidgetKit cache flow
**Priority:** High

## Goal

Fix two regressions in the home screen widget:

- it must visually track the same product language as the iOS app and macOS popover
- it must update immediately when revealed, without waiting for the host app to refresh first

## Approved Pattern

- Shared visual primitives stay in `NoSpoilersCore`
- Widget state selection continues to use `RaceWeekendResolver` and `SessionResolver`
- Widget freshness should come from WidgetKit timeline boundaries plus date-driven rendering, not ad-hoc app-side polling

## Plan

1. Replace precomputed widget countdown strings with date-backed widget view models so visible widgets can render current relative time.
2. Build multi-entry widget timelines at meaningful state boundaries:
   - off-season threshold crossings
   - session starts
   - session finished transitions
3. Tighten widget layout toward the app/popover chrome by using a blush header treatment and clearer footer separation.
4. Verify with the widget extension build and shared package tests.

## Verification

1. `swift test`
   Working directory: `NoSpoilersCore`
   Result: passed

2. `xcodebuild -project NoSpoilers/NoSpoilers.xcodeproj -scheme NoSpoilersWidgetExtension -destination 'generic/platform=iOS' -derivedDataPath /tmp/no-spoilers-widget CODE_SIGNING_ALLOWED=NO build`
   Result: passed

# Task 10: Basic iOS App And Home Screen Widget

**Status:** In Progress
**Depends on:** Existing `NoSpoilersCore` schedule fetch/cache flow
**Effort:** ~3-5 hours
**Priority:** High

## Goal

Ship a basic iOS app that mirrors the macOS menu bar product contract:

- spoiler-safe F1 schedule only
- current weekend plus session states
- no results, standings, or news

The most important output is the home screen widget. The app can stay minimal as long as it keeps the shared cache fresh and presents the same core information clearly.

## Existing Pattern

The approved shared boundary today is `NoSpoilersCore`:

- `ScheduleFetcher` owns network fetch
- `ScheduleCache` owns persistence
- `ScheduleStore` owns app-facing published state and refresh behavior
- `SessionResolver` owns session status resolution

The widget already reads from the shared App Group cache. The iOS app target currently exists but still contains template UI.

## Problem

The repo currently has:

- a working macOS menu bar app and popover
- a partially real widget implementation
- a placeholder iOS app target
- duplicated weekend-selection logic between the widget and macOS popover
- leftover template widget surfaces (`ControlWidget`, `LiveActivity`) that are not part of the product

If the iOS app is added by copying menu bar logic directly into more views, the repo will drift further into parallel implementations.

## Suggested Implementation

### 1. Converge shared schedule selection logic in `NoSpoilersCore`

Add one shared resolver for:

- current relevant weekend
- first non-finished session in a weekend
- next weekend after the current one

This should be used by:

- macOS popover
- iOS app home screen
- widget timeline entry generation

### 2. Replace the iOS template app with a basic schedule dashboard

The iOS app should:

- create one `ScheduleStore` with the shared App Group ID
- refresh on launch and when the scene becomes active
- trigger widget timeline reloads after refresh
- show the current weekend, session list, and the next weekend/off-season state

The UI can be simple SwiftUI. It does not need separate navigation or settings for this pass.

### 3. Tighten the widget to the real product

The home screen widget should:

- use the same shared weekend/session selection logic as the app
- support small and medium system families cleanly
- show the current or next relevant session state without spoilers
- remove template-only widget bundle entries that are not part of the product

### 4. Keep platform behavior aligned

Where macOS and iOS show the same concept, they should use the same resolver and status rules. Intentional presentation differences are acceptable; domain decisions should not drift by platform.

## Non-Goals

- adding settings, onboarding, deep linking, or account features
- adding results, live timing, or external metadata
- designing a highly polished iOS visual system
- implementing Live Activities or Control Widgets

## Acceptance Criteria

- iOS app no longer shows placeholder template content
- iOS app reads from `ScheduleStore(appGroupID:)`
- iOS app refreshes schedule data and reloads widget timelines
- widget bundle only exposes the real `NoSpoilersWidget`
- macOS popover, iOS app, and widget use one shared weekend-selection boundary
- changed code has build/test evidence at the smallest meaningful scope

## Verification Plan

1. Run `swift test` for `NoSpoilersCore`
2. Run a minimal `xcodebuild` build for the iOS app scheme with a workspace-local derived data path
3. Confirm the widget extension still builds as part of the iOS app scheme


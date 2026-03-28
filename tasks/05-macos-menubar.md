# Task 05: macOS MenuBarExtra

**Status:** TODO
**Depends on:** Task 03 (ScheduleStore working)
**Effort:** ~2 hours

## Goal

Implement the macOS menu bar item using `MenuBarExtra`. Shows the next session name and countdown as a text label in the menu bar. Click opens a popover with the full weekend view.

## Reference

`research/example-project/Sources/CodexBar/StatusItemController.swift` and the `MenuBarExtra` usage in the CodexBar app are the structural reference. Study how they manage the `MenuBarExtra` lifecycle and popover content before implementing.

## Menubar Label

The label in the menu bar shows the next session's name and countdown:

```
F1 Quali in 2h 15m
```

During a live session:
```
F1 Race — now
```

Off-season:
```
F1 in 12 days
```

Keep it short — menu bar space is limited. Abbreviate session names if needed (`FP1`, `Quali`, `Race`).

## Popover Content

Click opens a `MenuBarExtra` popover showing the full weekend view — same content as the iOS `.systemMedium` widget, rendered as a SwiftUI view from `NoSpoilersCore`.

The popover shows:
- Race weekend name and location
- Session list with state labels (watchable / now / countdown / scheduled time)
- Nothing else

## Implementation

```swift
@main
struct NoSpoilersMacApp: App {
    @StateObject private var store = ScheduleStore()

    var body: some Scene {
        MenuBarExtra(store.menuBarLabel) {
            WeekendPopoverView(store: store)
                .frame(width: 280)
        }
        .menuBarExtraStyle(.window)
    }
}
```

The `menuBarLabel` property on `ScheduleStore` returns the short menu bar string. Computed from the same session state logic used by the widget.

## Fetch Policy

The macOS app fetches on launch and every 6 hours via a `Timer` (or on next launch if the app is quit). No background fetch needed — the app is always running when the menu bar item is visible.

## Acceptance Criteria

- Menu bar label updates correctly as sessions approach, start, and end
- Popover opens on click, shows the full weekend
- No result data anywhere in the popover
- App builds and runs on macOS 14+
- `xcodebuild -scheme NoSpoilersMac` succeeds

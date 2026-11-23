# Local schedule dates in the iPhone app and widgets

Extend the accepted Mac departure board to the iPhone app, and prioritise making
the actual local start date/time visible in widgets alongside their countdowns.

## Checked scope and mechanisms

- iPhone `ContentView.sessionCard` is the real schedule list; `skeletonView` is a
  redacted loading shape. Use the existing `NoSpoilersSessionRow`,
  `NoSpoilersDepartureBoardText`, `DepartureBoardCycle`, `Theme.Motion` and
  `Strings.Schedule.sessionDateTime`. Preserve its minute-gated root `now`:
  faster root publishing previously interfered with the weekend pager.
- Mac `WeekendPopoverView.sessionTiming` is the accepted reference. iPhone may
  isolate cadence in SwiftUI `TimelineView`, as December decoration already does,
  while the Mac retains its own existing popover clock publisher.
- Widget inventory from `supportedFamilies`: systemSmall (`smallSessionRow`),
  systemMedium (`widgetSessionRow`, three closing sessions), systemLarge (same
  row, five closing sessions), systemExtraLarge (same row, complete weekend),
  accessoryRectangular and accessoryInline (`accessoryStateText`). Both gallery
  and live entry paths use these renderers. Loading/off-season carry no timings.
- The widget already carries upcoming start dates in `SessionState.upcoming`;
  reuse them without adding a model, storage field or data source. Keep existing
  relative `Text` so the system continues to update the countdown independently.
- The widget's large row currently has no detail and `Theme.Typography.rowDetail`
  traps there. Add the real detail role through this canonical owner, rather than
  a second row. Search found no other schedule date formatter or board mechanism.

## Decisions and acceptance

- iPhone: same five-second hold, half-second stagger and 0.4-second flip as Mac.
  Update only the visible list; pause animation in background, on other pages and
  with Reduce Motion. Reset on page/scene/schedule changes. Upcoming timing replaces
  the separate countdown badge; live, unconfirmed and finished badges remain.
- Widget: both local date/time and countdown remain visible. This is the stated
  recommended assumption while the optional widget-preference question is pending.
  Apple documents view archiving, no live data binding at rendering time, and
  timeline entries at least about five minutes apart; a continuous five-second
  loop would not reliably work. No extra reloads or timeline entries for cosmetics.
- Use a compact locale-aware widget date format without weekday; retain Mac and
  iPhone full-month formatting and existing formatter defaults elsewhere.
- Check all six widget render paths against the inventory, preserving session
  counts and race visibility. Inspect smallest/ordinary dimensions, long dates,
  both appearances and status boundaries. No outcome-bearing information.
- Run build/test commands serially with one worker. Obtain independent UI and
  spoiler-safety review, land on main and push; remove this task after completion.

## Source evidence

- Apple: `Keeping a widget up to date`, `Adding interactivity to widgets and Live
  Activities`, and `Animating data updates in widgets and Live Activities`.
  https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
  https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
  https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities

Implementation and verification pending.

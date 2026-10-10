# Make the Dynamic Island activity recognisable

Status: Complete. The user authorised committing after verification.

## Issue and scope

The user could not identify the countdown beside the iPhone camera as No Spoilers and reported
that the system clock was no longer visible. The current compact and minimal views use a generic
timer symbol. The expanded view has session details but no app name; after the scheduled start,
the compact trailing slot is empty. The earlier finish-confirmation hardening is already committed.

The user approved the researched design recommendation: use the existing app mark and brand
colour, keep the countdown compact before the scheduled start, show a status indicator afterwards,
and keep labelled timing, weekend and session details in the expanded view. No backend or
notification changes, releases or device/simulator installation are included.

## Plan

- [x] Reuse the bundled app artwork without an icon container in compact and minimal views.
- [x] Add the established wordmark to the expanded view; keep session and timing information legible.
- [x] Bound the compact countdown width and show neutral scheduled/unconfirmed indicators after it.
- [x] Verify the widget and iPhone builds and shared core tests; inspect layout and record what remains
  unverified on hardware.

## Evidence and constraints

Apple recommends recognisable app identity, a logo mark without its app-icon container, minimal
width, and coherent compact/expanded layouts:
https://developer.apple.com/design/human-interface-guidelines/live-activities
https://developer.apple.com/videos/play/wwdc2023/10194/

Uber explicitly iterated its arrival-time display to avoid confusion with the system clock:
https://www.uber.com/us/en/blog/live-activity-on-ios/

The system controls the surrounding status bar. The user supplied no iPhone screenshot of the
missing clock, so its cause is not established. Actual clock visibility and OS compositing require
a check on the user's iPhone. Build success alone cannot certify either.

## Verification

- `scripts/verify-core-tests.sh`: 147 tests passed, no failures (`tmp/island-core.log`).
- `scripts/verify-widget-build.sh`: final build succeeded (`tmp/island-widget.log`).
- `scripts/verify-ios-build.sh`: final build succeeded (`tmp/island-ios.log`).
- `git diff --check`: passed.
- An offscreen SwiftUI render using the production view components was inspected for upcoming,
  scheduled and unconfirmed compact, minimal and expanded layouts. The 48pt countdown slot fits
  `7:59:00`; the existing artwork renders with transparent margins and the minimal uncertainty
  badge stays inside its container. Artifact: `tmp/island-layout.png`. This is a layout check on
  macOS with a mocked camera gap, not an ActivityKit or iPhone status-bar rendering test.

Remaining hardware check: system-clock visibility, OS layout and coexistence with another Live
Activity on the user's iPhone. No device/simulator installation or release was performed.

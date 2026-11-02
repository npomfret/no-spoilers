# Add December decoration

## Issue

Implement the approved Christmas night treatment in the iPhone app, Mac popover and existing
widgets. The user approved native implementation after reviewing the mockups: midnight blue,
multicolour twinkling lights, snowfall and snow accumulating below the schedule.

## Accepted scope

- Main schedule surfaces in both apps, including their existing loading/empty/off-season states.
- All four existing system widget sizes: still lights, snow and drift. Rectangular Lock Screen
  accessory: a small monochrome snowflake. Inline accessory: retain its countdown.
- An immutable annual month/day window passed from each app/widget root. Defaults are local
  Gregorian 1 December through 26 December inclusive (off at midnight on 27 December).
- All three production roots use the 1 December default; the temporary preview override is removed.
- Preserve schedule behaviour, status colours, typography, paging, controls and the trademark disclaimer.
- Respect Reduce Motion; no continuous widget animation, no animation while app surfaces are hidden.
- Native implementation only; no release, store write, website changes or new widget families.
- No new dependency, runtime theme service, singleton or global configuration.

## Implementation plan

1. Use explicit date/time-zone/configuration inputs for the shared seasonal decision and widget boundaries.
2. Extend existing shared chrome/token roles with explicit December appearance values, preserving
   their ordinary appearance for callers outside this treatment.
3. Port the approved Canvas decoration once in Core. Keep its animation redraws isolated from
   schedule state. Reserve room so lights and drift never obscure text or controls.
4. Integrate the app roots and static widget rendering, including tinted/clear/background-removed
   widget modes. Add the configured start/end boundaries through the current bounded timeline planner.
5. Add meaningful calendar/timeline/contrast checks; run core tests with one worker and platform
   builds serially. Inspect deterministic native renders. Obtain agent review and resolve findings.

## Status

Complete. The user approved the visual result and requested a commit with the temporary start
reverted to 1 December. All three roots use the default configuration, and final serial
verification and pre-commit agent review passed. The working tree started with only this
research task untracked; main already contains two unrelated local completion commits, which
are preserved. No release, deployment or simulator changes were performed.

## Design and source evidence

Approved prototype: ignored `tmp/december-decoration/christmas-night.html`. PNGs in the same
directory: `christmas-night-{iphone,mac,widgets}.png`, `christmas-night-widget-extra-large.png`,
and `christmas-night-lock-screen.png`. Earlier restrained sketches were rejected.

Audited callers and shared components: iPhone ContentView/NoSpoilersApp; Mac ContentView and
AppDelegate; NoSpoilersWidget provider, entries, family views and backdrop; SharedChrome, Theme,
BrandPalette, TimelinePlanner and nearby core tests. Existing widget horizon is 48 hours with a
24-entry cap; it now includes the configured seasonal transitions alongside schedule transitions.

Apple guidance read during research, with Markdown copies in `tmp/logs/december-apple-*.md`:

- [Motion](https://developer.apple.com/design/human-interface-guidelines/motion) and
  [Reduce Motion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion).
- [Canvas](https://developer.apple.com/documentation/swiftui/canvas) and
  [pausable animation schedule](https://developer.apple.com/documentation/swiftui/animationtimelineschedule/init(minimuminterval:paused:)).
- [Widget update animations](https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities)
  last at most two seconds; the widgets use still scenes.
- [Accented/clear rendering](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass)
  replaces backgrounds and recolours content. Decorations must yield to the host presentation.

The prototypes were visually checked at desktop and 320px widths. App snow/brightness changed
while playing, paused frames stayed fixed, Reduce Motion and widget surfaces stopped playback.
Agent review found no remaining issues. This is design evidence, not native verification.

## Native verification

- `scripts/verify-core-tests.sh`: 159 tests, zero failures/errors, one worker. Report:
  `tmp/test-results/NoSpoilersCore.xml`; log: `tmp/logs/december-core-tests-commit.log`.
  Covers inclusive default dates, independent preview configuration, supplied local time zones,
  configured widget transitions, timeline deduplication/cap, seasonal contrast and drift clearance.
- `scripts/verify-mac-build.sh`: `BUILD SUCCEEDED` in `tmp/logs/december-mac-build-commit.log`.
- `scripts/verify-ios-build.sh`: `BUILD SUCCEEDED` in `tmp/logs/december-ios-build-commit.log`.
- `scripts/verify-widget-build.sh`: `BUILD SUCCEEDED` in `tmp/logs/december-widget-build-commit.log`.
- All commands ran serially. No UI tests, device installs, simulator mutation or remote writes.
- Native SwiftUI `ImageRenderer` proofs of the actual shared drawing/chrome were inspected for
  iPhone, Mac and small/medium/large widget canvases under `tmp/december-decoration/native/`.
  These use a macOS host and representative layouts; they are not full app or WidgetKit screenshots.
- `git diff --check` passed. Existing widget `Text` concatenation deprecations remain unchanged.

Review fixes already applied: a contrasting surface for the launch warning, preserved Mac
animation start across refreshes, host-supplied widget margins instead of assumed 16pt margins,
and matching iPhone snow canvas bounds through the bottom safe area. Final agent review of the
complete native diff and regression tests found no remaining issues; it confirmed the supplied
configuration reaches both widget decisions and timeline boundaries. A further pre-commit review
confirmed every runtime root now uses the 1–26 December default, with no temporary override left.

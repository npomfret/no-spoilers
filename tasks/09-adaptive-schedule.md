# Adapt schedule presentation to available width

Use full names and show countdown plus local date/time together when there is
room. Compact app layouts retain departure-board animation; widgets retain both
timings without alternation. Choose from actual available width, not device type.

Inventory before editing:
- Shared `NoSpoilersDepartureBoardText`: iPhone `ContentView.sessionCard` and Mac
  `WeekendPopoverView.sessionTiming`; both currently always flip upcoming rows.
- Shared `NoSpoilersSessionRow`: app rows, widget small row and widget list rows.
  Apps currently supply full names; widgets supply short names.
- Widget medium/large/extra-large use `widgetSessionRow` and `stateLabel`.
  Small uses `smallSessionRow`; rectangular uses `accessoryRectangularContent`;
  inline composes its name and timing in `Strings.Sessions.sessionUpcomingTiming`.
- Shared `Strings.Schedule.sessionDateTime` owns local date formatting; widget
  `Strings.Sessions.upcomingTiming` owns native live countdown composition.

Extend these existing mechanisms. Measure ordinary app text with ViewThatFits;
native widget temporal Text has no useful ideal width (prior rendering evidence
in docs/guides/brand.md), so use the widget's measured content width for its richer
timing variant. Keep finite timing columns. A 500pt content-width threshold, scaled
with caption size, reserves enough space for full list names plus local clock
time. Initial native renders showed independently fitting full labels could
compress temporal Text into truncation; list name and richer timing therefore
switch together. Apps, small and rectangular widgets use one shared name view
to choose from full/compact text widths. Inline retains its fixed compact format.

Acceptance: wide app details are static and show both values; narrow ones still
flip, respecting Reduce Motion. Roomy widgets show full names, native countdown
and local ordinal date/time; compact widgets keep both timings visible and shorten
names only when needed. Preserve schedule-only inputs and native timer updates.

Verify serial core tests, canonical iPhone/widget and Mac builds, native wide and
compact previews, then independent UI and spoiler audits. No release requested.

Verification:
- `scripts/verify-core-tests.sh`: 173 tests passed with one worker, including
  local ordinal clock time, 12-hour locale and midnight rollover cases.
- `scripts/verify-ios-build.sh -jobs 1`: passed, including the widget extension;
  rerun after the final app preview change. No compiler warnings.
- `scripts/verify-mac-build.sh -jobs 1`: passed with no compiler warnings.
- Native previews on NoSpoilers-iPad and NoSpoilers-iPhone: wide extra-large
  widget full names plus countdown/ordinal local clock time; medium short names
  with complete countdown/date; small full name with both timings. Shared app
  row preview shows full name and both values at 640pt, compact name and one
  animated timing face at 160pt. Evidence in root tmp/logs/adaptive-schedule.
- Independent UI and spoiler reviews found no substantive issues. WebStorm
  excludes worktree Swift files, so compiler builds supply diagnostics.
- Rectangular accessory name fitting, Dynamic Type boundaries and 12-hour
  widget rendering remain unverified visually. Locale formatting is unit-tested.
  No physical-device installation, release or production data writes performed.

Implementation and verification finished; landing and push pending.

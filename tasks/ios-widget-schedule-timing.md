# iPhone departure board and compact widget timing

Extend the accepted Mac departure board to the iPhone app. The widget is the
priority: show a compact live countdown followed by the local day/date in
parentheses, right-aligned, as requested (for example `2d 3h (Sat 15)`).

## Checked inventory and decisions

- iPhone `ContentView.sessionCard` is the real schedule; `skeletonView` remains a
  redacted loading shape. Reuse `NoSpoilersSessionRow`, `NoSpoilersDepartureBoardText`,
  `DepartureBoardCycle`, `Theme.Motion`, and `Strings.Schedule.sessionDateTime`.
  Keep minute-gated root `now`; a visible-list-only `TimelineView` owns faster
  drawing, as `DecemberDecorationView` already does. Pause offscreen, under sheets,
  in background and for Reduce Motion; reset on page, scene and schedule changes.
- Widget inventory: systemSmall (`smallSessionTime`), systemMedium (three closing
  sessions), systemLarge (five closing sessions), systemExtraLarge (complete list)
  through `widgetSessionRow`; accessoryRectangular and accessoryInline through
  `accessoryStateText`. Gallery/snapshot/live entries use these renderers. Empty
  and off-season states have no upcoming timing to display.
- All six families use the same `Strings.Sessions.upcomingTiming` composition:
  native live narrow date components plus parenthesised local weekday/day. Medium
  and large timing stays in the trailing badge; small/rectangular timing explicitly
  fills and aligns to the trailing edge. Inline keeps its single system-owned Text.
- iOS target floor is 26.4 (project settings). Use Apple's iOS 18+
  `Text(.durationOffset(to:), format: .units(... width: .narrow, maximumUnitCount: 2))`.
  These known system date/format types keep updating while
  the extension is inactive. Existing `CountdownFormatter.string` returns a snapshot
  String, so using it here would freeze between timeline entries. No parallel
  countdown algorithm, periodic timeline entries, reload loop or per-widget timer.
  The native formatter chooses its two largest units and switches to minutes as
  the start approaches. It uses a minus sign for future times. This is an explicit
  native presentation difference from the user's unsigned example, preserving
  reliable live updates. Timeline planning remains unchanged.
- Foundation supplies localized units, weekday names, date order and local date
  rollover through the canonical formatter. Do not hand-code English ordinal
  suffixes. Minutes remain available near the scheduled start.
- User accepted animated widget updates with both values visible. Use native
  numeric content transitions and stagger incoming row data changes by 0.15s;
  six rows finish within WidgetKit's two-second animation limit. Reduce Motion
  and reduced luminance disable explicit update animation. No repeating loop.
- The small header uses the feed's existing weekend name without the redundant
  Grand Prix suffix, and flexible spacers, to keep timing legible. The shared
  row omits its unused spacer when `Trailing` is `EmptyView`; this releases the
  small timing line's width instead of inventing another row. Other EmptyView
  consumers are the iPhone redacted skeleton; badge callers keep their spacer.
- Every widget uses the established short session names; medium/large rows use
  the canonical caption size without a redundant full-name detail. A finite
  136pt trailing column keeps archived live timing Text renderable and preserves
  the date. Medium rows use 22pt accents and 2pt vertical padding to retain three
  rows at the smallest supported height. Inline uses `SQ` for
  Sprint Qualifying. To select it without parsing labels, `SessionViewModel`
  retains existing `SessionKind` instead of duplicate name/shortName strings and
  derives its short label. Constructor inventory: five placeholders and two provider
  map paths, all migrated. IDs and states remain unchanged.
- Existing status labels, closing windows and session identities remain intact.
  No new external input, persisted schema or outcome-bearing information.

## Source and review evidence

- Apple: `Keeping a widget up to date`, `Animating data updates in widgets and
  Live Activities`, `Displaying dynamic dates`, `Text.init(_:format:)`,
  `TimeDataSource`, and Foundation `Date.ComponentsFormatStyle`.
  https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
  https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities
  https://developer.apple.com/documentation/swiftui/text/init(_:format:)-8sfgg
- SDK interfaces confirm `TimeDataSource.durationOffset(to:)` and
  `Duration.UnitsFormatStyle`'s `DiscreteFormatStyle` conformance. The app uses
  known platform formatting rather than a custom archived formatter.
- Search and caller inventory found the accepted Mac components, shared formatter
  and rows, and isolated December timeline. All are reused; no new helper type.
- Native rendering uses production widget source with only its family environment
  supplied by an adapter and registration/previews omitted. An iOS simulator QA
  host verifies actual iOS font metrics; Mac snapshots alone cannot.

The Home Screen host exposed an invalid range-bound configuration that static
previews did not: default ComponentsFormatStyle advances the upper bound, whereas
the ending-date source fixes it. Native scalar duration formatting removes that
fault and needs no precision-switch timeline entry. Read-only failure investigator
confirmed the error in extension and renderer logs; evidence stays in tmp/logs.
The host then exposed an ideal-width failure in archived temporal Text: a constant
Text control rendered, and replacing `fixedSize` with a finite timing column
restored the complete production widget. The final Home Screen capture visibly
shows FP3, Quali and Race, with right-aligned live countdown/date text.

## Verification and delivery

- Serial `scripts/verify-core-tests.sh`: 168 tests, zero failures (one worker).
- Serial `scripts/verify-ios-build.sh -jobs 1`: passed, including widget extension.
- Serial `scripts/verify-mac-build.sh -jobs 1`: passed for the shared row/token change.
- Signed build for `NoSpoilersApp` on `NoSpoilers-iPhone` passed; named simulator
  was created for this QA because the project-owned iPhone did not exist locally.
  Only that simulator was mutated. No remote or production writes.
- Final native iOS rendering matrix covers all six families, minimum Home Screen
  sizes, light/dark, long titles and nonzero countdown hours. Actual Home Screen
  medium capture renders all three rows and full trailing date. Read-only failure
  investigator confirmed no remaining temporal bound faults.
- A later screenshot did not advance its clock. An isolated three-line host
  control reproduced the same unchanged clock for the pre-existing native
  `.relative` Text, raw scalar Text and interpolated scalar Text across more than
  a minute. This does not establish a new scalar/interpolation defect. Live
  minute progression remains unverified in this headless simulator; the native
  documented temporal source is retained. Runtime VoiceOver, Reduce Motion and
  animation timing were code-reviewed rather than exercised.
- Independent UI and spoiler-safety reviewers inspected the final diff and all
  six family captures with no substantive findings. IDE inspection could not
  resolve the worktree files; Swift/Xcode compilation provided verification.
- Landing and push remain.

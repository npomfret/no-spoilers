# Expand widget countdown wording

User asks to use the newly available space for "in 3 days..." instead of "-3d...".
Retain the short names and right-aligned local weekday/date in every widget.

## Checked scope and implementation

- All six families use the existing target `Strings.Sessions.upcomingTiming`.
  Replace scalar duration formatting with the widget's original native
  `Text(date, style: .relative)`, inside a localized "in ... (weekday day)" Text
  template. Native units remain localized; no custom clock or timeline policy.
- Small uses the same factory with an explicit newline before the date; two
  lines and vertical fixed sizing preserve both values at 141pt. Horizontal
  fixed sizing stays disabled because archived temporal Text is flexible.
- Medium, large and extra-large retain canonical rows/badges. Widen the finite
  timing column to 172pt in existing `Theme.Badge`, without shrinking the font.
  Extend the existing inline SQ abbreviation through the target's short-name
  composition for every family, so Sprint Qualifying stays distinct and both
  names and full timings fit. All seven constructors still retain `SessionKind`.
- Rectangular keeps its single detailed timing Text. The inline edge checks
  exposed clipping for SQ with 23h59m and the wider Sprint name. Inline therefore
  asks the same factory for a concise native `Date.AnchoredRelativeFormatStyle`
  phrase and drops the redundant middle-dot separator. This documented platform
  distinction uses numeric presentation and abbreviated units ("in 3 days",
  "in 59 min") to keep names, words and dates visible without a custom formatter,
  static countdown, extra clock or smaller font. Existing incoming-data
  animation, Reduce Motion handling and iPhone departure board stay intact.
- Inventory: smallSessionTime, widgetSessionRow for medium/large/extra-large,
  accessoryStateText for rectangular and sessionUpcomingTiming for inline.
  No models, cache, schedule identity, state or timeline changes.

## Runtime evidence and verification

The scalar-format production widget rendered intermittently blank after
reinstall. Removing numeric transitions and row animations did not resolve it;
that trial was restored. An isolated three-line legacy-relative/raw-scalar/
interpolated-scalar control rendered all three, without advancing any timer
across more than a minute. This does not establish an interpolation defect or a
new ticking regression. Generic GPU errors alone did not explain the problem.
The expanded native-relative production widget renders its complete positive
countdown/date on the Home Screen (medium capture at 21:28), avoiding the scalar
format entirely. Live minute progression remains unverified in this simulator.

- Signed simulator build passes. Final native iOS matrix covers all six
  families, minimum sizes, both appearances and a long title. All names and
  expanded countdown/date values fit after the small vertical-size correction.
- Prior feature verification: 168 serial core tests, canonical iPhone/widget and
  macOS builds passed; the shared date formatter is unchanged by this follow-up.
- Final serial canonical iOS build passed, including the widget extension.
  The signed simulator build and all six native render families passed. Four
  225pt inline cases cover SQ at 23h59m, Sprint at three days, Sprint at 59min,
  and the wider Wednesday reference. The small actual Home Screen also renders;
  that fixture's primary state is unconfirmed, while the upcoming two-line
  layout is verified in the native 141pt capture.
- Independent UI review is clean after resolving its inline clipping finding.
  Spoiler review is clean; the final inline delta retains the same start date
  and schedule-only fields. Runtime ticking/accessibility remain unverified.
- Landing and push remain.

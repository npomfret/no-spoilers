# Widget ordinal dates and iPad timing layout

The widget shows `Fri 27` instead of `Fri 27th`. The supplied iPad screenshot
also shows clipped dates and uneven wrapping despite abundant horizontal space.

The shared date formatter owns widget dates. Its existing locale and local-time
tests are the reference. Add locale-formatted ordinal days while retaining the
platform's weekday/date order. Compact and full app formats retain their format.

The existing `widgetSessionRow`, shared session row and status badge own the
layout. Large and extra-large share the large canvas; forcing their timing to
172pt leaves only 148pt inside the pill. Reuse the row's available width up to
300pt, keep right alignment, and explicitly stack the date in the narrower
systemLarge family. The cap prevents native temporal Text from filling the wide
iPad row with a pill. Extra-large keeps a single line. Medium retains its 172pt
column and existing line wrapping.

Scope inventory: shared `.widget` date style reaches small, medium, large,
extra-large, accessory rectangular and accessory inline through widget
`Strings.Sessions.upcomingTiming`. Layout changes affect only the two large
families. No new data, timeline, model, storage or source is needed.

Acceptance: `Fri 27th`, correct ordinal suffixes including teen dates and local
rollover; full timing visible in wide iPad rows and consistently aligned in
narrow large rows. Verify core tests, widget build and native rendered layouts;
obtain independent UI and spoiler reviews before delivery.

Verification so far: all 170 tests passed via `scripts/verify-core-tests.sh` with
one test worker. Native Xcode previews show full countdown/date values in the
named iPad extra-large dark layout and named iPhone large/medium light layouts.
Large has consistent second-line dates; extra-large has matching one-line pills.
The inline preview renders blank in Xcode, so its minimum-width edge cases remain
unverified. WebStorm cannot inspect excluded worktree Swift files; the canonical
compiler build supplies diagnostics instead. `scripts/verify-widget-build.sh`
passed with no compiler warnings. Independent UI review inspected the final diff
and the three native previews and found no substantive issues. Spoiler audit
found no substantive issues in the supplied diff. No releases or remote data
writes were performed; Xcode rendered previews on the named iPad and iPhone.
Implementation and verification are complete; landing and push are pending.

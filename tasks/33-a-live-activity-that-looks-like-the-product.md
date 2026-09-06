# Task 33: a Live Activity that looks like the product

**Status: IN PROGRESS. Raised 2026-09-06 from a Lock Screen photograph.**

## The issue

On the afternoon of the Italian Grand Prix the user's Lock Screen held two Live Activities: the
BBC's football card above ours. Theirs: dark glass, two crests, the score large in the middle, the
minute under it, the competition named. Ours: an ivory card, the Grand Prix's name in ivory on it
and therefore invisible, *Race* in grey, and *In Progress* in red at title size as the biggest
thing on the card.

Three things, in order of severity:

1. **The name was invisible.** `activityBackgroundTint(Theme.Palette.surface)` hands the system an
   adaptive colour to paint the container with, and the system resolved it light while the text
   in the view resolved dark. The palette's roles are a pair by construction, and this is the one
   surface where the two halves of a pair are resolved by different parties.
2. **The loudest element said the least.** *In Progress* is a state; the reader wants a number.
   The race started at 14:00, which is calendar data, so the time since it started is arithmetic
   on a known instant and not a claim about the session. The view's own comment argued against a
   live clock, but the argument was about counting *down* to the estimated end, and it holds —
   that is still not done.
3. **No identity.** No wordmark, no flag, no round. The crests are the BBC's to use; the country
   flag and the Chivo wordmark are ours, and every Home Screen family already draws the flag.

## The change

- `SessionActivityWidget.swift`: no background tint and no system-action colour, so the Lock
  Screen draws its own material; text in the system's primary and secondary styles, as the
  accessory families already do; the card leads with wordmark and round, then flag and Grand
  Prix, then the session with a red dot and *In Progress* while live or *Finished* muted; the
  clock on the right is `.timer`, counting down to the start and up from it. The Dynamic Island's
  regions take the same pieces. The compact trailing slot now shows the clock in both phases.
- The flag needs the weekend's country, which a `Session` does not carry. `FeaturedSession` gains
  `countryCode` from the planner, which looks the weekend up by round and traps if it is missing;
  `SessionActivityAttributes` carries it to the extension. Nil stays nil and draws chequered, which
  is what `RaceWeekend.countryCode` means by it.
- `Theme.Header.flagHeight`'s note now names this flag as the second one off its ladder.

## Verification

- [x] `scripts/verify-core-tests.sh` — 118 tests, 0 failures, 2026-09-06; three new planner tests: the code is carried in both
      phases, it is the featured session's weekend and not another, an unknown weekend passes nil
- [x] `scripts/verify-widget-build.sh`, `scripts/verify-ios-build.sh` and `scripts/verify-mac-build.sh` — BUILD SUCCEEDED, 2026-09-06
- [ ] On the device: open the app during or before a session so the activity is re-requested,
      then look at the Lock Screen in both appearances and the Dynamic Island expanded. The name
      must be legible on both, the wordmark must be Chivo (the face registers per process and
      traps if it cannot), and the clock must count.

## 2026-09-06, evening: seen on the simulator

Nothing was within eight hours on any device by the time the card was rebuilt, and the push route
does not apply (the app never registers for push-to-start), so the feed was redirected instead:
`NoSpoilersConfig.feedRoot` now reads `NO_SPOILERS_FEED_ROOT`, the seam `screenshots.py` declined
on 2026-08-18 in the form of a "do not refresh" flag. The app still fetches — from a directory
served on localhost, which ATS allowed without an exception — and logs `feed redirected` on every
fetch so the picture cannot pass for the calendar.

What the pictures taught, each fixed in `SessionActivityWidget.swift`:

- `Text(_:style: .timer)` rendered as *38 minutes* in words, wide enough to truncate the Grand
  Prix. `Text(timerInterval:)` gives digits, and on a locked simulator the seconds draw as `––`
  the way an always-on display does; on a fresh lock they count.
- `Text(timerInterval:)` asks for the width of its widest string. With `layoutPriority` it starved
  the left column to *Bel…* and wrapped *In Progress* a syllable per line; with `fixedSize` the
  row overflowed the card, clipping the wordmark on the left and pushing the clock off the right.
  It is bounded to `clockMaxWidth` now.
- 16 by 12 of padding read as tighter than every card in the product. The card takes the iOS
  card geometry's insets, which is the standard rather than a pair picked from the scale.
- The eight-hour look-ahead is `SessionActivityAttributes.lookAhead`, shared by the controller
  and the extension's countdown range, rather than a number in each.
- The widget extension does not inherit the environment and refetches the calendar into the
  cache; an app woken warm then reads it and ends the activity before its own fetch lands. A
  cold launch before each lock is the procedure, and the testing guide says so.

- [x] Simulator, iPhone 17, iOS 26.5: upcoming and live, light and dark, all four read.
- [ ] Device, on a real session: still worth the look — the Dynamic Island was not captured.

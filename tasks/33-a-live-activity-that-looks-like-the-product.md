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

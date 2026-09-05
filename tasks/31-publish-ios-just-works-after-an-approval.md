# Task 31: Publish iOS has to just work when the button is pressed

**Status: DONE, 2026-09-05.**

## The issue

Task 30 made `release.sh` refuse a version App Store Connect has already approved, before the
archive. Build 21 of `Publish iOS` (18:31 UTC, `publish.args` empty, revision `1a014b0`) was the
first run to meet that check, and it did what it was built to do: two seconds, *ios 1.1.2 is closed
to new builds: it is READY_FOR_SALE*, nothing archived, no bump commit. It was also the fourth red
publish of the day for pressing the same button the same way, and the user's answer was that the
build should just work when the button is pressed.

The empty form of `scripts/ci-publish-ios.sh` meant "ship the version the project holds". That is
the right meaning while a train is open, since a train fills with TestFlight builds by shipping the
same version again and again, and the wrong one from the moment Apple approves the version until
somebody types the next one into `publish.args`. Nothing on the CI path knew which of the two it
was in.

## Brainstorming

- **Ask App Store Connect, and open the next patch version when the train is closed
  (chosen).** `appstore_status.py` already has `closed_train`; expose it as `--train PLATFORM
  VERSION` with the exit contract `--spent` uses. The wrapper asks it when given no version, ships
  the project's version on 0, fetches tags and ships `suggest_next_version` on 3, and stops on
  anything else. Task 30 rejected an automatic bump as "a guess about which digit to increment";
  the user has overruled that for the button, and the guess is confined to the wrapper, which is
  the one caller that cannot be asked. `release.sh` is unchanged and still ships only what it is
  told.
- **Put the choice in `release.sh`.** Its no-argument form is an interactive prompt defaulting to
  `suggest_next_version`, which is a person's flow; giving the engine a "guess for me" mode would
  put the guess in every caller. Rejected.
- **Always ship the next patch version from CI.** Opens a train per press, so TestFlight would
  never see two builds of one version from this path. Rejected.
- **Make `publish.args` required.** Moves the typing to every press instead of one per approval.
  Rejected; it is the opposite of the request.

## The plan

1. `appstore_status.py --train PLATFORM VERSION`: 0 open, 3 closed, 1 unanswered. Shares the
   platform check, the client and `closed_train` with `--spent` rather than copying them.
2. `ci-publish-ios.sh`: the version is decided after the preflight, because the question needs
   the key step 2 asserts. `--check` reports the version it would ship.
3. `docs/guides/building.md` and `docs/guides/important-code.md` record the behaviour and the
   reversal of task 30's rejection.

## Tracking

- All three done 2026-09-05, in one commit with this file.
- `git fetch --quiet --tags origin` precedes `suggest_next_version` in the wrapper because a
  TeamCity checkout does not carry tags and the helper skips tagged versions.
- Not done, and not needed now: a loop for the case where the suggested version is itself closed.
  It cannot happen without a version being approved that was never tagged and never the project's,
  and `release.sh --spent` refuses it loudly if it does.

Verification:

- [x] `scripts/verify-python-selftests.sh`: appstore_status 112 cases, 0 failures; the other four unchanged
- [x] `bash -n scripts/ci-publish-ios.sh`
- [x] Read-only against the real record: `--train ios 1.1.2` exits 3 naming READY_FOR_SALE; `--train ios 1.1.3` exits 0; `--train` with `--spent` refuses
- [x] `scripts/ci-publish-ios.sh --check` on the laptop: *1.1.2 is closed, so this run opens 1.1.3. This run would ship iOS 1.1.3.*
- [ ] A green `Publish iOS` with `publish.args` empty, opening 1.1.3

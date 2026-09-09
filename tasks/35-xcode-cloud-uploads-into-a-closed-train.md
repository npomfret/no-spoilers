# Task 35: Xcode Cloud uploads into a closed train

**Status: DONE. Raised and closed 2026-09-09. Delete this file.**

Closed two ways, and the second makes the first permanent: 1.1.4 opened a train so the refusals
stopped, and task 36 then disabled the Xcode Cloud workflow and removed the path, so nothing can
upload without going through `release.sh`'s four preflight questions again.

1.1.3 reached the store on both platforms (macOS 2026-09-07, iOS 2026-09-07; task 34). The
checkout still holds `MARKETING_VERSION = 1.1.3`, so every Xcode Cloud run since has archived,
uploaded and been refused by email. The most recent is run 125:

```
ITMS-90186: Invalid Pre-Release Train - The train version '1.1.3' is closed for new build
            submissions
ITMS-90062: The value for key CFBundleShortVersionString [1.1.3] in the Info.plist file must
            contain a higher version than that of the previously approved version [1.1.3]
```

Both say the same thing: an approved version stops taking builds. Measured on 2026-09-09:

```
appstore_status.py --train ios   1.1.3 -> closed to new builds: it is READY_FOR_SALE (exit 3)
appstore_status.py --train macos 1.1.3 -> closed to new builds: it is READY_FOR_SALE (exit 3)
```

## Why the existing guard did not catch it

`scripts/release.sh:327` already asks this question, and its comment describes this exact
failure from 2026-09-05. It is not reached, because there are two upload paths and only one
of them is `release.sh`:

- `release.sh` (via `ship.sh`, `ship-ios.sh`) — takes its build number from App Store Connect,
  runs the `--spent` preflight, refuses before archiving. Correct today.
- Xcode Cloud (`NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh`) — stamps `CI_BUILD_NUMBER` and
  archives whatever `MARKETING_VERSION` the checkout holds. No version check of any kind.
  This is where builds 104, 112, 118 and 125 came from.

The hook is the right place: a non-zero exit there fails the action before anything is
uploaded, which is already how the core-tests gate works.

## Brainstorming: what the hook can ask

- **Ask App Store Connect** (`appstore_status.py --train`) — the authoritative question, the
  same one `release.sh` asks. Needs an API key inside Xcode Cloud. There is none, and
  `docs/guides/building.md:50` records that this repository has no CI secrets at all.
  Configuring one is a change in Xcode Cloud's settings, not in this repository.
- **Ask git for an approved-version tag** (`ios/vX.Y.Z`, `macos/vX.Y.Z`) — no credential
  needed. Rejected as the primary check: the tag only appears when a person remembers to run
  `tag_approved.py`, and a guard that depends on the step after the one that went wrong is not
  a guard. (Written here first as "it has never run, there are no such tags", which was wrong:
  `ios/v1.1.2` existed and a `tail -10` hid it. The reasoning does not depend on the count.)
- **Ask TeamCity to fail `main` instead** — the agent runs on the developer's own machine and
  can reach the key. This moves the failure earlier than the archive, which is better, but it
  is a `.teamcity/settings.kts` change and that file is not in this repository.

## The plan

1. **Open the 1.1.4 train.** Bump `MARKETING_VERSION` to 1.1.4 with `set_marketing_version`,
   which proves the stamp against every configuration. Unblocks the next Xcode Cloud run on
   its own. — DONE, see Verification.
2. **Guard the Xcode Cloud path.** ~~The hook asks App Store Connect, with the key supplied as
   Xcode Cloud secret environment variables.~~ **Dropped 2026-09-09, unbuilt.** The guard existed
   to stop an unwatched path uploading; task 36 removed the path instead, which is the stronger
   answer — there is nothing left to guard, and no secret had to be put on a build machine to do
   it. The three secret variables were never created.

## Verification

- [x] `set_marketing_version 1.1.4`, 2026-09-09: `MARKETING_VERSION = 1.1.4 in all 6
      configurations`, proved against the file by the setter's own count
- [x] `CURRENT_PROJECT_VERSION = 10022` still in all 6 configurations — the committed build
      number is frozen by task 32 and this change does not touch it
- [x] Both trains open afterwards, 2026-09-09: `--train ios 1.1.4` and `--train macos 1.1.4`
      both "still taking builds", exit 0
- [x] All four build entry points green at 1.1.4, 2026-09-09: `verify-ios-build.sh`,
      `verify-mac-build.sh`, `verify-widget-build.sh` all `** BUILD SUCCEEDED **`, and
      `verify-core-tests.sh` 118 tests, 0 failures
- [x] Step 2 dropped rather than built, see above

## Residual risk

None from this task. The bump buys one train, but nothing uploads automatically any more: when
1.1.4 is approved, the next release is a person running `scripts/ship.sh`, and `release.sh`
refuses a closed train in preflight — which is the check that was missing all along.

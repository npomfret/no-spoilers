# Task 35: Xcode Cloud uploads into a closed train

**Status: IN PROGRESS. Raised 2026-09-09.**

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
  needed. Rejected as the primary check: `tag_approved.py` has never run, there are no such
  tags in the repository today, and the tag only appears when a person remembers to write it.
  A guard that depends on the step after the one that went wrong is not a guard.
- **Ask TeamCity to fail `main` instead** — the agent runs on the developer's own machine and
  can reach the key. This moves the failure earlier than the archive, which is better, but it
  is a `.teamcity/settings.kts` change and that file is not in this repository.

## The plan

1. **Open the 1.1.4 train.** Bump `MARKETING_VERSION` to 1.1.4 with `set_marketing_version`,
   which proves the stamp against every configuration. Unblocks the next Xcode Cloud run on
   its own. — DONE, see Verification.
2. **Guard the Xcode Cloud path.** Blocked on a decision that is not this repository's to
   make: where the hook gets an App Store Connect key. Recorded above; awaiting the owner.

## Verification

- [x] `set_marketing_version 1.1.4`, 2026-09-09: `MARKETING_VERSION = 1.1.4 in all 6
      configurations`, proved against the file by the setter's own count
- [x] `CURRENT_PROJECT_VERSION = 10022` still in all 6 configurations — the committed build
      number is frozen by task 32 and this change does not touch it
- [x] Both trains open afterwards, 2026-09-09: `--train ios 1.1.4` and `--train macos 1.1.4`
      both "still taking builds", exit 0
- [ ] **`scripts/verify-ios-build.sh` has not run.** Xcode cannot run under the agent's
      sandbox at all: `xcodebuild` dies in package resolution with `sandbox-exec:
      sandbox_apply: Operation not permitted`, and even `-list` loses CoreSimulator and the
      fs-event stream. The project file's structural soundness is unproven here; `agvtool`
      wrote it, and the setter counted 6/6, but that is not a build.
- [ ] Step 2 not started: no credential path for the hook

## Residual risk

Until step 2 lands, nothing stops the next run archiving a version the store already has.
The bump in step 1 buys exactly one train: when 1.1.4 is approved, the same failure returns.

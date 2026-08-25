# Task 22: the local release path has been rewritten and never run

**Status: OPEN. Carried out of tasks 14 and 17 when they were closed on 2026-08-15 — everything
else in both is done and proven, and this is the one thing neither could close from a keyboard.**

`scripts/release.sh` was substantially rewritten on 2026-08-13 and 2026-08-14 and **has not shipped
anything since**. Its last real run was 2026-08-12, before both rewrites.

**Corrected 2026-08-16.** This file originally said the script had not run at all since
`CURRENT_PROJECT_VERSION` was moved to the `10000` band, and that the two-band design had therefore
never been tested. Checking the app record showed otherwise: the 2026-08-12 run uploaded macOS
`10001` and iOS `10002`, so the bands **have** met, in both trains, without colliding. That claim is
struck from the list below. What is left is genuinely untested — the current script, and the
one-build-number fix that landed after that run.

Everything in this file is unproven-by-running, not suspected-broken. Each piece was verified as far
as it can be without an actual release: `bash -n` clean, argument validation exercised, the
failed-archive path proven on a throwaway repo, `--build` proven to pin and to be idempotent.

## What has never been exercised

- **`scripts/ship.sh` shipping all three channels from one version.** Mac App Store, macOS
  Developer ID and iOS App Store in one run, version-locked, one build number. This was the last
  unchecked box in task 17, and the one-build-number fix that made the claim true is itself part of
  what has not run. The 2026-08-12 run is the counter-example that made the fix necessary rather
  than evidence for it: two auto-bumps three minutes apart (`ba44cad`, `4461978`) put **10001 on
  macOS and 10002 on iOS** for one release, which is exactly what `--build` now pins.
Discharged by running it on 2026-08-22:

- ~~**`scripts/ship-ios.sh` after the rewrite**, and specifically that its upload does not collide
  with a CI build number.~~ It ran, and shipped `1.1.2 build 10003` — the whole path, archive
  through App Store Connect, under the current script. No collision: the 1.1.2 train held Xcode
  Cloud's numbers and took `10003` without complaint. What the run cost is recorded below, because
  it went wrong in two ways that had nothing to do with the rewrite.

## What the first real run actually found — 2026-08-22

Neither fault was in the list above, and neither would have been found by rehearsing the script.

- **The build shipped ungated.** `ci_pre_xcodebuild.sh` runs `verify-core-tests.sh` before every
  Xcode Cloud archive and its comment calls that line "the only thing standing between a broken
  commit and TestFlight". It was, literally: `release.sh` ran no tests at all, which nobody noticed
  while CI was the ordinary path. Xcode Cloud ran out of compute quota the same week, and the gate
  left the path entirely without a single line changing.
- **The build reached the testers with an empty *What to Test* note**, as every 10000-band build
  always had. `testflight_distribute.py` asked the Xcode Cloud run for the commit and left the note
  alone when no run claimed the number — which is every build `release.sh` uploads.

Both are fixed, and the fixes are in `docs/guides/building.md`. The general lesson is the one worth
keeping: **the local path was never a second-class copy of the CI path, it was a path missing the CI
path's safeguards**, and that stayed invisible for as long as it was the exception.

Discharged by observation on 2026-08-16, not by running anything:

- ~~**The two build-number bands, against each other.**~~ Measured on the live app record: macOS
  1.1.1 holds `10001` alongside Xcode Cloud 15, 16 and 17; iOS 1.1.1 holds `10002` alongside 1
  through 17. No collision, and no upload was refused. This was the last unchecked box in task 14
  and it is now answered. The band separation still rests on nothing but the committed
  `CURRENT_PROJECT_VERSION`, so the "do not lower it" warning in `docs/guides/building.md` stands.

## Hazards to expect on the first real run

These are known and documented, and are why the first run deserves watching rather than launching
and walking away.

- **A spent `(version, build)` pair does not fail the build.** It compiles, archives, goes green,
  and dies minutes later at *"Preparing build for App Store Connect failed"*. Check what the train
  already holds before shipping; `docs/guides/building.md` has the query, and note that both
  expired builds and `CANCELED` Xcode Cloud runs still occupy their numbers.
- **The Homebrew tap is a sibling checkout** (`../homebrew-tap`) that nothing here clones.
  Preflight now fails at the top of the run if it is missing, which is the half of the dry run that
  already exists.
- **A failure leaves the working tree dirty and unpushed on purpose.** The version bump is edited in
  before the archive and committed only after it, and nothing reverts a file you may also have been
  editing. An `ERR` trap says so.

## The other half: `release.sh` has no dry run

**Half of this is now answered, 2026-08-22.** Preflight grew the two checks that a rehearsal was
most wanted for — a dirty working tree and a `(version, build)` pair App Store Connect already
holds — plus the test gate, and all three run before anything is edited, built or uploaded. What
remains unrehearsed is the second half of the run: export, notarize, upload, tag, GitHub release,
tap push.

The two writing tools have opposite safety postures. `testflight_distribute.py` is dry-run by
default and needs `--apply`. `release.sh` has no dry run at all and pushes to two repositories.

Deferred deliberately on 2026-08-14 rather than dropped: a real `--dry-run` has to guard **every**
mutating command in the engine — `sed`, `git commit`, `git push`, `xcodebuild archive`, `notarytool`,
`altool`, `gh release`, the tap edit and its push — and a partial one is worse than none, because it
teaches you to trust a rehearsal that skipped the step that would have failed.

Half its value is already delivered by preflight: the most-cited benefit was knowing the run cannot
die on a missing tap after notarization has completed and the GitHub release is public.

It pairs with the item above because the same run answers both: the first real ship is also the
last chance to find out what a rehearsal would have needed to cover.

## Verification

- [ ] One `ship.sh` run puts the same version **and the same build number** on all three channels
- [x] `scripts/ship-ios.sh` completes under the current script — 2026-08-22, `1.1.2 build 10003`
- [x] The uploaded `release.sh` build number lands in the 10000 band and collides with nothing
      Xcode Cloud has uploaded — observed 2026-08-16 on the 2026-08-12 uploads, see above
- [ ] `scripts/ci_health.py` still PASS afterwards, both products resolving by id
- [ ] `docs/guides/building.md` updated with whatever the first real run turns out to have been
      wrong about — it is the canonical description and currently describes an untested design

## A second path now exists, and it has been run — 2026-08-25

**TeamCity ships iOS.** `Publish iOS` on `ci.snowmonkey.co.uk`, manual, gated on `Verdict`, running
`scripts/ci-publish-ios.sh` over the same `release.sh`. It uploaded `1.1.2 build 10008` on
2026-08-25 — archive, sign, export, validate, upload — in three minutes once an agent was free.
Xcode Cloud having no quota is what made this worth building; the full account is under *Publishing
from TeamCity* in `docs/guides/building.md`.

**It does not discharge anything in this file.** What is still unrehearsed here is `ship.sh`
shipping three channels from one version on a laptop, and none of that ran. The iOS App Store
channel of `release.sh` is now exercised twice over — locally on 2026-08-22 and from CI on
2026-08-25 — and the macOS and Developer ID channels are exactly as unproven as they were.

**Three things the CI run found that the local path had not.**

- **A failed export still leaves a pushed bump commit.** The commit is placed after the archive on
  the reasoning that the build number is then real. Build 738 archived, pushed
  `bump to v1.1.2 (build 10007)`, and then failed the export — so 10007 exists in this repository's
  history and nowhere else. Harmless to Apple, misleading to a reader.
- **The *What to Test* note is not being found on this path.** `testflight_distribute.py` looks for
  the `bump to vX.Y.Z (build N)` commit and reported *"no Xcode Cloud run and no ship commit"* for
  build 10008, whose bump commit is on `main`. Testers get a blank note. Not diagnosed.
- **The installed distribution profiles expire.** Roughly a year, and the failure reads as a cloud
  signing permission error rather than an expiry. Admin role on `ASC6H3SL2D` is the durable fix.


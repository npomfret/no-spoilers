# Task 22: the local release path has been rewritten and never run

**Status: OPEN. Carried out of tasks 14 and 17 when they were closed on 2026-08-15 — everything
else in both is done and proven, and this is the one thing neither could close from a keyboard.**

`scripts/release.sh` was substantially rewritten on 2026-08-13 and 2026-08-14 and **has not shipped
anything since**. It has also not run at all since `CURRENT_PROJECT_VERSION` was moved to the
`10000` band, which means the central claim of the two-band design has never been tested against the
thing it is meant to avoid.

Everything in this file is unproven-by-running, not suspected-broken. Each piece was verified as far
as it can be without an actual release: `bash -n` clean, argument validation exercised, the
failed-archive path proven on a throwaway repo, `--build` proven to pin and to be idempotent.

## What has never been exercised

- **The two build-number bands, against each other.** `release.sh` counts from 10000; Xcode Cloud
  uses its run number. Nothing enforces the separation but the committed
  `CURRENT_PROJECT_VERSION` — and no `release.sh` upload has happened since the bump, so a run of
  both paths against one app record has never been observed. This was the last unchecked box in
  task 14.
- **`scripts/ship.sh` shipping all three channels from one version.** Mac App Store, macOS
  Developer ID and iOS App Store in one run, version-locked, one build number. This was the last
  unchecked box in task 17, and the one-build-number fix that made the claim true is itself part of
  what has not run.
- **`scripts/ship-ios.sh` after the rewrite**, and specifically that its upload does not collide
  with a CI build number.

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
- [ ] The uploaded `release.sh` build number lands in the 10000 band and collides with nothing
      Xcode Cloud has uploaded
- [ ] `scripts/ci_health.py` still PASS afterwards, both products resolving by id
- [ ] `docs/guides/building.md` updated with whatever the first real run turns out to have been
      wrong about — it is the canonical description and currently describes an untested design

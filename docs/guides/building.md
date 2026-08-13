# Building Guide

Canonical build and compile policy for this repo.

## Rules

- Use the repo's approved build and verification entry points.
- If the repo has not standardized wrappers yet, verify the real Swift package or Xcode entry point before running anything.
- Choose the smallest meaningful build or compile scope first.
- Do not bypass build failures or toolchain errors.
- Report exact commands and outcomes.

## Current state

- Canonical build wrappers live in `scripts/` and force HOME/Foundation home, DerivedData, SwiftPM scratch space, source packages, and module caches into repo-local `tmp/` paths.
- Use `scripts/verify-mac-build.sh` for the macOS app build. It builds scheme `NoSpoilers` for `generic/platform=macOS`.
- Use `scripts/verify-ios-build.sh` for the iOS app build. It builds scheme `NoSpoilersApp` for `generic/platform=iOS`; if that scheme is absent, stop and inspect the real shared schemes before substituting another command.
- Use `scripts/verify-widget-build.sh` for the widget extension build. It builds target `NoSpoilersWidgetExtension` with Debug `iphoneos` settings and target-build-compatible output paths.
- Do not replace these wrappers with ad-hoc `xcodebuild` invocations unless the wrapper is wrong for the touched scope; update the wrapper instead when a command becomes canonical.

## Continuous delivery

Three delivery paths exist. They must not be merged or duplicated.

- **The App Store is the core product on both platforms; Homebrew is an add-on.** Decided 2026-08-13, and `release.sh` now says so: `--platform` and `--channel` are both **required** (there is no default, because the only default was `macos` + `developer-id`, so asking for nothing shipped the add-on), and in `--channel both` the App Store upload runs **before** the Developer ID / Homebrew channel. Do not swap that back — both export from the same already-valid archive, and with Homebrew first a notary timeout killed the run before the store upload was attempted. A Homebrew failure still fails the run; it can no longer cost you the upload. See `tasks/17-release-process-asymmetry.md`.
- `scripts/release.sh` is the single release engine. `scripts/ship-*.sh` are thin argument wrappers over it. **Releases run on your machine, never in CI**, and `scripts/ship.sh` is the whole of it: macOS Developer ID, Mac App Store and iOS App Store in one run, version-locked, every platform shipped whether or not its source changed.
  - **There was a `.github/workflows/release.yml` claiming to do the Developer ID channel on a `v*` tag. It was deleted on 2026-08-12 because it had never worked — ten tag pushes since March, ten failures, each dying in about twelve seconds importing a certificate from `secrets.DEVELOPER_ID_CERT_P12`, which was never set. The repository has no secrets at all.** It was a duplicate of what `ship.sh` already does locally, so nothing was lost, and every release you have ever shipped went out from a laptop. What it cost was worse than nothing: a red cross on every release tag, teaching everyone that a failed run on a release is normal.
- Xcode Cloud archives scheme `NoSpoilersApp` on every push to `main` and uploads to TestFlight. **The build arrives attached to no tester group and nobody can install it until it is put in one** — that is a command somebody runs, deliberately, not a post-action. Task 14 Phase 1 step 6 is the argument. Its hook lives in `NoSpoilers/ci_scripts/`, beside the Xcode project — Xcode Cloud ignores a `ci_scripts` directory at the repository root.
  - `ci_pre_xcodebuild.sh` runs `scripts/verify-core-tests.sh` and then stamps `CURRENT_PROJECT_VERSION` to `CI_BUILD_NUMBER`. It is the only hook.
  - **There is deliberately no `ci_post_clone.sh`.** One existed, writing `NoSpoilers/TestFlight/WhatToTest.en-GB.txt` from the commit subject, and App Store Connect read that file on some runs and not others — builds 3 and 9 carried their own note, builds 4, 5 and 6 all carried build 3's. Nothing in any artifact records whether the file was read, so a working run and a broken one are indistinguishable. Do not reinstate it; `testflight_distribute.py` writes the note over the API instead, and two mechanisms writing one note is how you get a stale one nobody can explain.
- **The two upload paths are kept apart by the committed `CURRENT_PROJECT_VERSION`, which starts at `10000`.** `release.sh` increments from there (10001, 10002, …); Xcode Cloud uses its run number. Do not lower that committed value — build numbers only ever increase, and the bands would start to overlap.
- No CI script can influence the build number that reaches App Store Connect: Xcode Cloud rewrites `CFBundleVersion` to `CI_BUILD_NUMBER` when it exports the IPA, after the hook and after the archive. The stamp exists so the archive agrees with the upload, not to control it. Task 14 Phase 0 Decision 1 has the measurements.
- Xcode Cloud does not gate delivery on its TEST action, so the `verify-core-tests.sh` call in `ci_pre_xcodebuild.sh` is the only test gate on TestFlight builds. Removing it leaves runs green and the gate gone.
- **An Xcode Cloud build reaches no tester group on its own.** `scripts/testflight_distribute.py` is the step that hands it over — dry-run by default, `--apply` to act, `--apply --submit` to send an external build for Beta App Review. Nothing runs it for you; that is Phase 1 step 6's deliberate choice, and forgetting it looks exactly like success.
  - **Newest means most recently uploaded, not the highest build number.** The two upload bands above make numeric order meaningless: a fresh CI build is `5` while last month's manual upload is `10001`.
  - It touches internal groups only unless `--group` names one, so no default can ever feed the public link.
  - **It also repairs the *What to Test* note**, since the hook's file is only sometimes picked up. It asks the Xcode Cloud run for the commit — a build's version is its run number — and writes `whatsNew` over the API. The test is not "is there a note" but "does the note name *this* build": the failure mode is a well-formed note about somebody else's commit, which reads as correct and describes changes the tester does not have.
- `scripts/appstore_status.py` reads what App Store Connect holds for both platforms and writes nothing. Keep it that way: `release.sh` and `testflight_distribute.py` are the only things here that write, and the split is what makes the report safe to run at any time. It is stdlib-only Python and needs no venv or install, and it owns the shared token signing, app lookup and build selection that the distribute script imports.
  - **Its `TESTFLIGHT` section answers "what can a tester install right now", not "does a build exist".** It walks the unexpired iOS builds newest-first asking each `?include=betaGroups` until one is in a group, and prints how far behind that has fallen — `testers can install build 4, 5 builds behind build 11`. **Being behind is never a warning.** Delivery is a manual command, so the newest build reaches nobody after every push; warning about it would leave the report permanently red and take the exit code with it. Only installing *nothing* is reported under NEEDS YOU.
- **The two Python scripts hold different App Store Connect keys, and that is the point.** The report runs on the Developer-level key `S394C74APG`; only `testflight_distribute.py` uses the App Manager key `ASC6H3SL2D`. A Developer key reads every endpoint involved and is then refused the write with an empty `403` that looks like a malformed request.

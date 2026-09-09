# Task 36: TeamCity replaces Xcode Cloud

**Status: IN PROGRESS. Raised 2026-09-09. Xcode Cloud is off and out of the repository. The
TeamCity button and the certificate it needs are outstanding, and until they exist a release is a
`scripts/ship.sh` run on a laptop.**

Xcode Cloud is to stop being a delivery path, and TeamCity is to become the one that ships.
Decided 2026-09-09, after Xcode Cloud was found archiving every push to `main` against an
approved version — 1.1.3, closed since 2026-09-07 — and being refused by email each time,
`ITMS-90186` and `ITMS-90062`, up to run 125.

The owner presses a button per release rather than shipping every push.

## What exists today

- **Xcode Cloud** — **disabled 2026-09-09**, `PATCH /v1/ciWorkflows/7A43B70B…` with
  `isEnabled: false`, confirmed by `ci_health.py` reading `DISABLED`. It built on every push,
  archived both platforms and uploaded, and asked none of the four questions `release.sh` asks —
  which is how it spent four days uploading a closed train. The workflow record and both its
  ARCHIVE actions are intact, so re-enabling it is the same PATCH with `true`.
- **`scripts/release.sh` on a laptop** — the single release engine, with all four safeguards.
  Stays exactly as it is. Nothing in this task adds a second engine.
- **TeamCity `TestFlight` button** — hands an already-uploaded build to the Internal group.
  Stays. It distributes; it does not build.

`Publish iOS` did run `release.sh` on the agent from 2026-08-25 and was deleted 2026-09-06
(`e08e838`) with `scripts/ci-publish-ios.sh`, because Xcode Cloud had come back. That script
is the foundation here: it is thin, it asserts the three things `release.sh` assumes about a
machine, and it has shipped real builds.

## The blocker, and it is not a code one

**The agent cannot sign a Mac App Store package.** It holds an *Apple Distribution*
certificate and no *Mac Installer Distribution* one, which is why `Publish iOS` covered one
platform. A `.pkg` for the Mac App Store needs the installer certificate; nothing in this
repository can create it.

So the achievable end state is:

- **iOS App Store from TeamCity** — proven, worked from 2026-08-25.
- **macOS App Store from TeamCity** — only after the installer certificate is on the agent.
- **Homebrew / Developer ID** — stays on the laptop. It needs a *Developer ID Application*
  certificate, notarization credentials and the `../homebrew-tap` checkout. Moving it buys
  little and widens what the agent holds.

## The plan

1. **Restore the CI entry point as `scripts/ci-publish.sh`**, recovered from
   `e08e838^:scripts/ci-publish-ios.sh` and generalised from one platform to a required
   `--platform ios|macos`. Keeps its assertions, its `--check` mode, and its rule for
   choosing a version. Still thin: `release.sh` remains the only engine.
2. **Add the macOS assertion** — the installer identity — so the macOS button fails in
   seconds with what is missing rather than after an archive.
3. **Remove Xcode Cloud from the repository** (detail below).
4. **TeamCity configuration** — a `Publish` configuration per platform, or one with a
   platform parameter, on the `NoSpoilers_Main` VCS root, with a snapshot dependency on
   `Verify`. Unlike `TestFlight`, this one archives, so it must build a revision that passed.
   **The five verification configurations still hold no credential and must not gain one**;
   `Publish` is separate and holds them.

   This repository has no `.teamcity/settings.kts` — configurations are UI-owned — and
   `scripts/teamcity.py` is GET-only by design. So the button is created by the owner, or by
   a separately approved action. It is not something this task can land on its own.

## The removal sweep

Live code:

- `NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh` — delete, and the `ci_scripts` directory with
  it. Its test gate already exists in `release.sh` since 2026-08-22, so nothing is lost.
- `_version.sh: set_build_number` — the hook is its only caller. Delete once the hook goes.
- `scripts/ci_health.py` — its entire subject is whether Xcode Cloud is wired correctly.
  Delete, and remove it from `verify-python-selftests.sh`.
- `scripts/testflight_distribute.py` — asks `/v1/ciProducts/.../buildRuns` for the commit
  behind a build, to write the *What to Test* note. With Xcode Cloud gone every build carries
  a `build/N` tag, so the git path it already has becomes the only path. Remove the Xcode
  Cloud branch and the product lookup.

Prose, where the history explains why a safeguard exists and should be kept as history rather
than deleted: `README.md`, `docs/guides/building.md`, `docs/guides/important-code.md`,
`scripts/appstore_status.py`, `scripts/tag_approved.py`,
`NoSpoilersCore/.../AppVersion.swift`, and `.claude/skills/release-and-delivery/SKILL.md`.

Task files 26, 34 and 35 are records of what happened and are not rewritten.

## What the owner has to do

1. Decide whether macOS ships from TeamCity. If yes, install a *Mac Installer Distribution*
   certificate on the agent. If no, macOS stays a `scripts/ship.sh` run on the laptop.
2. Create the `Publish` configuration in TeamCity, or approve its creation.
3. ~~Turn off the Xcode Cloud workflow~~ — **done 2026-09-09.** `PATCH /v1/ciWorkflows/7A43B70B…`
   with `isEnabled: false`. Pushes no longer produce runs, and the ITMS emails stopped.

## What landed

- `scripts/ci-publish.sh` — recovered from `e08e838^`, `--platform ios|macos` now required, the
  installer-identity assertion added for macOS, the wrapper and the version question chosen by
  platform. Everything else is as it was, including `--check`.
- Deleted: `NoSpoilers/ci_scripts/` and its hook, `scripts/ci_health.py` and its selftest entry,
  `set_build_number` from `_version.sh`, `source_commit` and the `find_ci_product` plumbing in
  `testflight_distribute.py`, and `ci_products`/`select_ci_product`/`find_ci_product` plus their
  eight selftest cases in `appstore_status.py`.
- Rewritten as history: `README.md` (the whole *Checking Xcode Cloud is wired* section is gone),
  both guides, `appstore_status.py`, `tag_approved.py`, `AppVersion.swift` and the
  release-and-delivery skill. Task 26's `ci_health.py` checkbox is dropped rather than left
  unsatisfiable.

## Verification

- [x] `scripts/verify-python-selftests.sh` — five scripts green, 2026-09-09 (189 cases; was six
      scripts and 206 before `ci_health.py` went)
- [x] `scripts/verify-core-tests.sh`, `verify-ios-build.sh`, `verify-mac-build.sh`,
      `verify-widget-build.sh` all green, 2026-09-09
- [x] No reference anywhere to a deleted file: `ci_health`, `ci_pre_xcodebuild`, `ci-publish-ios`,
      `ci_scripts`, `find_ci_product`, `source_commit` — every remaining hit is prose naming them
      as removed
- [x] `ci-publish.sh` refuses a missing `--platform` and an unknown one, exit 1 both
- [ ] **`ci-publish.sh --check` has never run on the agent.** It cannot be run anywhere else: the
      question it exists to answer — whether the login keychain is unlocked in the agent's own
      session — has no answer from an SSH shell or a sandbox. `security find-identity` returns
      zero identities here.
- [ ] **Nothing has shipped through the new path.** Confirmed 2026-09-09 from both ends: the only
      `build/N` tag in the repository is `build/10023` (2026-09-05, a `release.sh` run on the
      laptop), and TeamCity has never run a build under a `Publish` configuration. The `Verify`
      chain is green at `3a2fbc1` and `TestFlight` has run — but `TestFlight` distributes an
      already-uploaded build, it does not archive one.

## Residual risk

The macOS half is unproven in a way the iOS half is not: `ci-publish-ios.sh` shipped iOS 1.1.2
build 10008 on 2026-08-25, and no macOS archive has ever been made on the agent. The installer
identity string in the script is the conventional one and has not been read off the certificate
this repository will actually use.

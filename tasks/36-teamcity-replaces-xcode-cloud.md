# Task 36: TeamCity replaces Xcode Cloud

**Status: OPEN, nothing landed. Raised 2026-09-09.**

**The removal was written and then reverted the same day, unshipped.** `f3d9586` deleted the
Xcode Cloud path from the repository while the Xcode Cloud *workflow* was still switched on and
still building every push — builds 126 to 130 landed during that session, from those very commits.
Deleting `ci_pre_xcodebuild.sh` therefore did not stop Xcode Cloud; it stripped the
`verify-core-tests.sh` gate off it and left the only thing standing between a broken commit and
TestFlight gone, with no `Publish` configuration yet built to take over. The revert put it back.

**The ordering this proved:** build and prove the replacement, turn the old path off at its source,
and only then delete the code. The code is the last step, not the first.

Xcode Cloud is to stop being a delivery path, and TeamCity is to become the one that ships.
Decided 2026-09-09 after task 35 found Xcode Cloud archiving every push to `main` against an
approved version and being refused by email each time.

The owner presses a button per release rather than shipping every push.

## What exists today

Three paths, and the delivery half of the map is wrong:

- **Xcode Cloud** — builds on every push, archives both platforms, uploads. Quota ran out
  2026-08-22 and reset 2026-09-05. Unguarded: it asks none of the four questions
  `release.sh` asks. This is what task 35 is about, and it is what goes.
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

## What the owner has to do, in this order

1. Install a *Mac Installer Distribution* certificate on the agent, in the keychain it runs under.
   Decided 2026-09-09 that macOS ships from TeamCity too.
2. Create the `Publish` configuration in TeamCity — one press per platform, on the
   `NoSpoilers_Main` VCS root, with a snapshot dependency on `Verify` (unlike `TestFlight` this one
   archives, so it must build a revision that passed). Then run `ci-publish.sh --platform macos
   --check`, which ships nothing, and after that ship one real build through it.
   Configurations here are UI-owned: there is no `.teamcity/settings.kts`, and `scripts/teamcity.py`
   is GET-only by design.
3. **Turn off the Xcode Cloud workflow in App Store Connect.** Until this happens Xcode Cloud
   builds every push, whatever this repository says — that is what the revert above is about.
   Nothing here can do it.
4. Only then re-land the removal.

## Where the work is

The whole change exists and is known-good against the repository's own checks; it is in `f3d9586`
and its revert. Recovering it is `git revert` of the revert, not writing it again. It was verified
at the time: all five entry points green, 189 selftest cases across five scripts, the three builds
and the core tests, and no dangling reference to a deleted file.

What it is waiting for is steps 1 to 3 above, in that order. Do not re-land it before step 3.

## Residual risk, when it does land

- **`ci-publish.sh --check` has never run on the agent**, and cannot run anywhere else: the
  question it exists to answer — whether the login keychain is unlocked in the agent's own
  session — has no answer from an SSH shell or a sandbox. `security find-identity` returns zero
  identities from the agent tooling here.
- **The macOS half is unproven in a way the iOS half is not.** `ci-publish-ios.sh` shipped iOS
  1.1.2 build 10008 on 2026-08-25; no macOS archive has ever been made on the agent. The installer
  identity string in the script is the conventional one and has not been read off the certificate
  this repository will actually use.

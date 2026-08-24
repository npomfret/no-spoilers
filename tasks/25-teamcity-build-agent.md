# Task 25: put the build on TeamCity

**Status: PROPOSED. Raised 2026-08-24, nothing done.**

Reference: `/Users/nickpomfret/projects/snowmonkey-proxy-common/docs/TEAMCITY-AGENTS.md`, which is
the server owner's document and was verified against the running server on 2026-08-23. Everything
about the *server* below is quoted from it; everything about *this repo* was read out of this repo.

## Why, and the history that has to be answered first

**This is the third attempt at CI for this project**, and the first two are the reason to be
careful rather than a reason not to try.

- `.github/workflows/release.yml` was deleted on 2026-08-12 **having never once succeeded**
  (`docs/guides/important-code.md` §20).
- **Xcode Cloud has no compute quota left**, confirmed 2026-08-22: runs 33, 34 and 35 were all
  cancelled 5-8 seconds after creation and `POST /v1/ciBuildRuns` answers `500`
  (`tasks/23-native-functionality-for-4-2-2.md`). Every build since has been a local
  `scripts/release.sh` run.

So the honest statement of value is not "automate the release" — that has been tried twice and the
release path is currently the one thing that *does* work. It is **"stop finding out at ship time
that a target does not compile."** The five verification wrappers already exist, already run
offline, and nobody runs all five before every commit.

## The constraint that decides the whole shape

**The agent must be a Mac.** Everything this repo builds is Xcode: `verify-ios-build.sh`,
`verify-mac-build.sh` and `verify-widget-build.sh` all invoke `xcodebuild`, and
`verify-core-tests.sh` runs a SwiftPM test suite whose target platform is
`arm64e-apple-macos14.0`. §7 of the server doc is explicit that the server installs nothing —
"whatever your build needs must already be on the agent."

**This rules out Option A, the recommended Docker agent**, and every convenience that comes with
it. Option B, the standalone JDK-based agent from §4, on a Mac with Xcode, is the only shape
available. Decide *which* Mac before anything else — running it on Nick's daily machine means CI
compiles compete with interactive work for the same Xcode and the same DerivedData.

Second gate, from §1: **the licence allows three agents estate-wide** and they are shared across
all projects. Confirm a slot is free with the server owner before installing anything; this may be
taking the last one.

## Phase 1 — verification only, no secrets

This is the whole of the recommendation. It needs no signing identity, no App Store Connect key,
and no push credentials, because none of these commands sign, upload or write:

| Command | What it proves |
|---|---|
| `scripts/verify-core-tests.sh` | the shared package, 88 tests |
| `scripts/verify-python-selftests.sh` | the four Python tools, 167 cases, offline |
| `scripts/verify-ios-build.sh` | the iOS app compiles |
| `scripts/verify-mac-build.sh` | the Mac app compiles |
| `scripts/verify-widget-build.sh` | the widget extension compiles |

**The three Xcode wrappers are already close to hermetic** and this is why they are a good first
CI job: each one exports `HOME`, `XDG_CACHE_HOME` and three module-cache paths into the repo's own
`tmp/`, and each passes `CODE_SIGNING_ALLOWED=NO`. An agent needs Xcode and a checkout; it does not
need a keychain.

Open question to settle by running it once: `verify-core-tests.sh` and the Python selftests were
written for a developer's machine, and whether they also survive the redirected `HOME` has not been
checked here.

## Phase 2 — the release path. Do not start this with Phase 1 unproven

`scripts/release.sh` is the single release engine and it is a much harder CI target than it looks:

- **It signs.** `xcodebuild archive` with `DEVELOPMENT_TEAM=6FZN56WC8G`, then `-exportArchive`
  against `ExportOptions-AppStore.plist` or `ExportOptions-DeveloperID.plist`. A CI agent needs the
  certificates and provisioning profiles in a keychain it can unlock unattended.
- **It notarizes**, via `xcrun notarytool` with either explicit `--notarytool-key/-key-id/-issuer`
  or the keychain profile `no-spoilers-notarytool`.
- **It uploads**, via `xcrun altool --upload-app --apiKey/--apiIssuer`.
- **It writes to the repository.** `git commit -m "bump to vX.Y.Z (build N)"` followed by
  `git push`, plus `git tag`/`git push origin vX.Y.Z`, and for the Homebrew channel a commit and
  push in a second checkout. So the agent needs push rights to `main`, and **any trigger on push to
  `main` will retrigger itself** — that is the first thing to get wrong.
- **Its preflight refuses a dirty tree** (`release.sh:179`), which a CI checkout satisfies, and
  refuses a `(version, build)` pair App Store Connect already holds, which needs the read-only key
  at `~/.appstoreconnect/private_keys/AuthKey_S394C74APG.p8` — a path under the real `HOME`, not
  the redirected one Phase 1 relies on.

None of that is impossible. All of it is credential handling on a shared free-tier server whose
REST API deliberately has no route from outside an SSH tunnel, and it buys back a path that
currently works.

## Security notes carried over from the server doc

- The admin access token lives at `~/Documents/projects/teamcity/accesskey.txt` on Nick's machine.
  It is **full admin scope**, and §9 says plainly: not in any repo, do not commit it. Nothing in
  this repo should ever read it.
- `/app/rest` is behind Google SSO and **the token does not work against the public host** — REST
  access needs `ssh -N -L 8111:$TC_IP:8111 root@snowmonkey.co.uk`, forwarded to the *container's*
  bridge IP, looked up fresh each time. §9 explains why widening the nginx carve-out is refused
  rather than pending.
- Agent identity lives in the `agent-conf` volume; losing it burns a licence slot.

## Verification

Phase 1 is verified by the build configuration going green on a commit that is known good, and then
red on one that is known bad — deliberately break a target once and confirm CI says so. A CI job
that has only ever been green has not been tested.

## Open

- **Which Mac.** Nothing else can be decided first.
- Is a licence slot free?
- Whether to trigger per push or nightly. Five Xcode builds is not a fast job, and the three build
  wrappers each do a clean-ish build into their own `SYMROOT`.
- Phase 2 is written down so the cost is visible, not because it is recommended.

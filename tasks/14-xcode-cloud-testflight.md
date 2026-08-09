# Task 14: Xcode Cloud → TestFlight for the iOS app

**Status:** TODO
**Depends on:** nothing — the App Store Connect record, API key, and signing already work via `scripts/ship-ios.sh`
**Effort:** ~2 hours, most of it spent on the two decisions in Phase 0

## Goal

A push to `main` builds the iOS app on Apple's infrastructure and puts it on TestFlight, without
anyone running `scripts/ship-ios.sh`.

The point is **not** to save the typing. A local build compiles your working tree, so a commit can be
broken while every command on your machine is green. Xcode Cloud is the only thing that builds what
was actually pushed.

## Overview

```
push to main → Xcode Cloud workflow → Archive (scheme NoSpoilersApp)
                                          ↓
                            TestFlight internal testing → tester's phone
```

`scripts/ship-ios.sh` stays. This runs alongside it: Xcode Cloud for continuous internal builds,
`release.sh` for versioned App Store submissions. The macOS app is **out of scope** — it ships via
Developer ID and Homebrew (Task 08) and must not be archived here.

---

## Phase 0: Two decisions to make before touching anything

These are the only parts of this task that are specific to this repo, and both will cost a rejected
upload if they are got wrong.

### Decision 1: the build number

`CURRENT_PROJECT_VERSION` is currently `8` and `MARKETING_VERSION` is `1.0.22`, both maintained by
`release.sh` off git tags.

**App Store Connect accepts a version/build pair exactly once**, and refuses anything that repeats
it. Xcode Cloud exposes `CI_BUILD_NUMBER` — the run number — which starts at **1**. Stamping it
naively would try to upload build 1, 2, 3 for a marketing version that already has a build 8, and
every one of those is either a duplicate or arrives out of order.

Three ways out, in order of preference:

1. **Offset the run number.** `CURRENT_PROJECT_VERSION = CI_BUILD_NUMBER + 1000`. Monotonic, never
   collides with anything `release.sh` has produced, and obvious in TestFlight which channel a build
   came from. Pick the offset once and write it down.
2. **Give Xcode Cloud its own marketing version** (say `1.0.22-ci`) so the build-number space is
   separate. Cleaner in theory, more moving parts, and clutters the version list.
3. **Do not stamp at all.** Only viable if you never want two Xcode Cloud builds of the same version,
   which defeats the purpose.

**Take option 1 unless there is a reason not to.** The script in Phase 3 assumes it.

### Decision 2: what plays the part of a test gate

There are **no Xcode test targets in `NoSpoilers.xcodeproj`.** The tests live in the `NoSpoilersCore`
SwiftPM package and run through `swift test` (`scripts/verify-core-tests.sh`). Xcode Cloud's `TEST`
action needs an Xcode test target and a test plan, so as things stand there is nothing for it to run.

That turns out to matter less than it sounds, because of this:

> **Xcode Cloud does not gate delivery on the test action.** Actions run concurrently, nothing waits
> on anything, and the distribution audience belongs to the archive action alone. A run whose tests
> failed still puts a build on a phone — observed directly on another project: test action red at
> 13:18:47, build VALID on TestFlight at 13:19:37.

So a `TEST` action would be a report, not a gate, even if you built one. The options:

- **Run `swift test` from `ci_pre_xcodebuild.sh`.** That script is allowed to fail, and a failing
  pre-build hook fails the archive action before anything is uploaded. **This is a real gate**, which
  the `TEST` action is not. Cost: the tests run before every xcodebuild invocation, on every push.
- **Add an Xcode test target** hosting the package tests, plus a test plan. More faithful to how
  Xcode Cloud expects to work, gives you the test report in the UI, and still is not a gate.
- **Neither**, and rely on `verify-core-tests.sh` locally. Acceptable for internal-only builds; be
  honest that CI is then a compiler, not a check.

Recommendation: the first. It is three lines in a script you are writing anyway, and it is the only
option that actually stops a broken build reaching a tester.

---

## Phase 1: Create the workflow

1. Open `NoSpoilers/NoSpoilers.xcodeproj` in Xcode and go to **Integrate → Create Workflow**.

   Not `Product`. That menu moved in Xcode 14 and most tutorials still say Product. The Integrate
   menu only appears with a project open and an Apple ID signed in under Settings → Accounts.

2. Pick **`NoSpoilersApp`** as the scheme. Both `NoSpoilers.xcscheme` and `NoSpoilersApp.xcscheme`
   are shared, and `NoSpoilersApp` is the iOS application target
   (`com.apple.product-type.application`, deployment target 26.2). Choosing the wrong one will build
   the Mac app in a pipeline meant for TestFlight.

3. Start condition: **branch changes on `main`**.

   Leave `autoCancel` on. It is why `CANCELED` appears in the run history with nobody having
   cancelled anything.

4. Delete the default `Build` action and add a single **Archive** action:
   - Platform: iOS
   - Scheme: `NoSpoilersApp`
   - **Distribution: internal testing**

   An archive action with no distribution audience produces an artifact and stops. That state is
   indistinguishable from success in every screen Apple shows you.

5. Create an internal tester group in App Store Connect **before the first build**, with
   *access to all builds* enabled.

   That flag can only be set at creation. Patching it afterwards returns
   `409 ENTITY_ERROR.ATTRIBUTE.NOT_ALLOWED`, and the only fix is to delete the group and make it
   again. Without it, every build needs assigning to the group by hand.

---

## Phase 2: Where the CI scripts go

Both scripts live in `NoSpoilers/ci_scripts/` — **beside `NoSpoilers.xcodeproj`, not at the
repository root.** Same for the `NoSpoilers/TestFlight/` notes directory.

```
no-spoilers/
  NoSpoilers/
    NoSpoilers.xcodeproj
    ci_scripts/            <- here
    TestFlight/            <- and here
```

Putting either at the repository root produces no error at all — just nothing happening. Both scripts
must be committed executable (`chmod +x`).

Add `NoSpoilers/TestFlight/` to `.gitignore`; it is generated per build.

---

## Phase 3: `ci_scripts/ci_pre_xcodebuild.sh`

Sets the build number, and gates on the core tests per Decision 2.

```sh
#!/bin/sh
set -eu

# Offset chosen in Task 14 Phase 0. Keeps Xcode Cloud's run numbers clear of the
# build numbers release.sh produces, which reached 8 before this existed.
BUILD_OFFSET=1000

echo "ci_pre_xcodebuild: run ${CI_BUILD_NUMBER:-<unset>}, commit ${CI_COMMIT:-<unset>}"

# Not every stage has a checkout. This hook runs before EACH xcodebuild
# invocation, and `test-without-building` runs on a machine holding the built
# products and nothing else, with CI_PRIMARY_REPOSITORY_PATH unset. Under
# `set -u` that is an exit 1 one stage after the script did its job correctly.
if [ -z "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  echo "ci_pre_xcodebuild: no checkout in this stage, nothing to stamp"
  exit 0
fi

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "ci_pre_xcodebuild: CI_BUILD_NUMBER is unset" >&2
  exit 1
fi

# The gate. A TEST action would not stop the archive; this does, because a
# failing pre-build hook fails the action before anything is uploaded.
"${CI_PRIMARY_REPOSITORY_PATH}/scripts/verify-core-tests.sh"

build=$((CI_BUILD_NUMBER + BUILD_OFFSET))
cd "${CI_PRIMARY_REPOSITORY_PATH}/NoSpoilers"

xcrun agvtool new-version -all "${build}"

# Trust the file, not the tool: agvtool reports success in cases where it
# changed nothing at all.
if grep -q "CURRENT_PROJECT_VERSION = ${build};" NoSpoilers.xcodeproj/project.pbxproj; then
  echo "ci_pre_xcodebuild: CURRENT_PROJECT_VERSION is now ${build}"
else
  echo "ci_pre_xcodebuild: agvtool exited 0 but the project did not change" >&2
  grep "CURRENT_PROJECT_VERSION" NoSpoilers.xcodeproj/project.pbxproj >&2
  exit 1
fi
```

Notes:

- `agvtool new-version -all` updates **every** build configuration, which is what you want here:
  `NoSpoilersWidgetExtension` has its own `CURRENT_PROJECT_VERSION` and an app whose extension
  disagrees about its build number is rejected at upload.
- It is idempotent and exits 0 when the value is already set, so running it twice in a run is fine.
- It also writes `CFBundleVersion` into any `INFOPLIST_FILE` it finds. Redundant, and harmless — the
  checkout is thrown away with the run.
- `verify-core-tests.sh` writes into `tmp/` under the repo root and sets its own `HOME`; check it
  behaves on a clean runner the first time, and drop the call if it turns out to need something the
  runner does not have.

### If this step fails

The log for it is inside the action's `LOG_BUNDLE` artifact, as `ci_pre_xcodebuild.log`. See Phase 6.

---

## Phase 4: `ci_scripts/ci_post_clone.sh`

Writes the TestFlight *What to Test* note from the commit being built, so nobody has to remember to.

```sh
#!/bin/sh
notes_dir="${CI_PRIMARY_REPOSITORY_PATH}/NoSpoilers/TestFlight"
out="${notes_dir}/WhatToTest.en-GB.txt"

echo "ci_post_clone: writing ${out}"
mkdir -p "${notes_dir}" || exit 0

subject=$(git -C "${CI_PRIMARY_REPOSITORY_PATH}" log -1 --format=%s "${CI_COMMIT}" 2>/dev/null)
short=$(echo "${CI_COMMIT}" | cut -c1-12)

if [ -n "${subject}" ]; then
  printf '%s\n\nBuild %s from %s\n' "${subject}" "${CI_BUILD_NUMBER:-?}" "${short:-unknown}" > "${out}"
else
  printf 'Build %s from %s\n' "${CI_BUILD_NUMBER:-?}" "${short:-unknown}" > "${out}"
fi

cat "${out}"
exit 0
```

**Opposite rule to the other script: a non-zero `ci_post_clone.sh` fails the entire run.** Every path
ends at `exit 0` — no missing tester note is worth a failed delivery. Do not put the test gate here.

Both scripts echo on success deliberately. An empty log is indistinguishable from a script that never
ran, and that ambiguity cost a diagnosis on the project this came from.

---

## Phase 5: What is already correct in this repo

Checked against the working tree, so you do not go looking:

| Thing | State | Why it matters |
|---|---|---|
| `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` | **set** on the app configurations | Without it every build arrives as *Missing Compliance* and testers cannot install it until somebody answers by hand, per build |
| iOS app icon | **1024×1024, no alpha** | An icon set that declares its slots and holds no image files compiles cleanly and is refused at upload with a single unexplained line. The primary icon is present, so this trap does not apply here |
| Dark / tinted icon slots | declared, no files | Not a failure — iOS generates them. Supply real ones if you care how they look |
| App Store Connect API key | `AuthKey_S394C74APG.p8`, issuer `69a6de6e-…` | Already used by `ship-ios.sh`, already has the rights, already proven |
| Signing | automatic, team `6FZN56WC8G` | Xcode Cloud manages its own certificates; `ExportOptions-AppStore.plist` is not used by it |

The icon is worth re-checking after any redesign:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  NoSpoilers/NoSpoilers/Assets.xcassets/AppIcon.appiconset/icon.png
```

The primary icon must be 1024×1024 RGB with **no alpha channel**. The dark variant may have
transparency; the tinted one may not.

---

## Phase 6: Diagnosing a failure

Xcode Cloud's failures are often one sentence with nothing behind them —
`Preparing build for App Store Connect failed` is the whole message, and the UI has no more. The
route is the App Store Connect API, using the key you already have.

1. `GET /v1/ciProducts/{id}/buildRuns?limit=25&sort=-number`

   **`sort=-number` is not optional.** Without it the endpoint answers oldest-first, so you get the
   first fifteen runs ever recorded and go on getting them while newer runs fail unseen.

2. `GET /v1/ciBuildRuns/{id}/actions` — actions carry their own status, so you can see the archive
   failed while everything else passed.

3. `GET /v1/ciBuildActions/{id}/issues?limit=50` — filter to `issueType != WARNING`. A healthy build
   carries dozens of warnings and the one error is buried among them.

4. `GET /v1/ciBuildActions/{id}/artifacts` — each has a `downloadUrl`. `LOG_BUNDLE` holds the script
   logs. For an upload failure, download the `ARCHIVE` artifact and read the built `Info.plist`
   inside it: that is the thing App Store Connect rejected, and it will tell you what is missing when
   nothing else will.

Auth is an ES256 JWT — `aud` of `appstoreconnect-v1`, key id in the header, issuer in the claims,
lifetime no more than 20 minutes. `openssl` will sign it; the only fiddly part is that OpenSSL emits
DER (two *signed* integers) and JOSE wants the raw 64-byte `r||s` pair, so the leading-zero strip and
the pad back to 32 bytes are both load-bearing. Get either wrong and roughly one signature in 256 is
malformed — it works locally and 401s intermittently.

Two red herrings worth naming:

- **`~/Library/Developer/Xcode/UserData/XcodeCloud/*.sqlite` lies.** It read zero products while App
  Store Connect had failed builds listed all along. It is a cache, not a record.
- **A "Start Build" button that appears to do nothing is a build failing fast.** Five clicks produced
  five real builds, all compile failures, with the assistant screen never moving.

---

## Verification

Done when all of these hold, with evidence:

- [ ] A push to `main` produces a run that reaches `SUCCEEDED`.
- [ ] The build appears in TestFlight as `VALID`, not *Missing Compliance*.
- [ ] Its build number is `CI_BUILD_NUMBER + 1000` and is higher than anything `release.sh` shipped.
- [ ] The widget extension's build number matches the app's.
- [ ] *What to Test* in TestFlight shows the commit subject and short hash.
- [ ] Breaking a `NoSpoilersCore` test and pushing produces a **failed run and no new TestFlight
      build**. This is the one that proves the gate, and it is the only way to know Decision 2 worked.
- [ ] `scripts/ship-ios.sh` still works afterwards and does not collide with a CI build number.

---

## Open risks

- **`verify-core-tests.sh` on a clean runner.** It creates `tmp/` directories and overrides `HOME`.
  Untested outside this machine. If it misbehaves, the gate goes away and Decision 2 needs revisiting
  rather than the script being quietly dropped.
- **Compute allowance.** Archiving on every push spends against 25 hours a month that do not roll
  over. If `main` is busy, move the start condition to a tag or manual trigger. Adding the core tests
  to every build makes each run longer.
- **The gate is a script, not a feature.** Anyone who deletes the `verify-core-tests.sh` line from
  `ci_pre_xcodebuild.sh` removes the gate silently, and the run stays green. Nothing in Xcode Cloud
  will report that.
- **TestFlight builds expire 90 days after upload** and then stop launching, with nothing to explain
  it beyond "Expired Build".
- **Two release paths to one App Store record.** Xcode Cloud and `release.sh` both upload under the
  same bundle identifier. The offset keeps their numbers apart; nothing enforces it but this task
  file.

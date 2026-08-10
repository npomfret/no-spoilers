# Task 14: Xcode Cloud → TestFlight for the iOS app

**Status:** IN PROGRESS — the chain works end to end. A push archives, the tests gate it, the build
uploads `VALID` and `APP_STORE_ELIGIBLE` with the archive and IPA agreeing on the number (runs 4 and 5,
builds 4 and 5), `scripts/testflight_distribute.py --apply` hands it to a group, and a tester now sits
at `INVITED` having been invited by that hand-over alone. **The gate is proven** — run 8 carried a
deliberately failing test, failed at the pre-build hook, and delivered nothing. The *What to Test*
note is no longer Apple's to lose: the distribute command writes it. `appstore_status.py` reports
which build the testers can actually install.

**One thing is left, and it is not code.** `release.sh` has not run since the `10000` bump, so the
two build-number bands have never been exercised against each other.

**The chain is closed on a human.** Build 13, from commit `7fec1d7`, was installed on a phone and
launched on 2026-08-10 — push, archive, test gate, upload, `testflight_distribute --apply`, someone
tapping Install. Every step of this task has now been demonstrated on the real thing rather than
inferred from a green status.
**Depends on:** nothing — the App Store Connect record, API key, and signing already work via `scripts/ship-ios.sh`
**Effort:** ~2 hours, most of it spent on the two decisions in Phase 0

## Live configuration

Recorded because none of it is discoverable from the repo, and `GET /v1/ciProducts` will not always
show it (see Phase 1, "When Xcode will not let you create the workflow").

| Thing | Id |
|---|---|
| Xcode Cloud product `NoSpoilersApp` | `1F3A0BBD-DC5B-44FA-A767-65B3E14A433B`, created 2026-08-10 |
| Workflow `Default` | `6EE7E8AE-43B3-4A88-94AB-729C6EE45E6B` |
| App record | `6761343835`, `pomocorp.NoSpoilers.NoSpoilersMac` — one record, iOS and macOS both |
| Internal group | `e4840ac3-284b-4b6c-a41f-b400d6d0fac1` |
| Repository | `npomfret/no-spoilers`, `b36f1212-d272-4b37-9ba0-50c3277fd1f2` |

Workflow as it now stands: container `NoSpoilers/NoSpoilers.xcodeproj`, branch `main`, `autoCancel` on,
one action — `ARCHIVE` / scheme `NoSpoilersApp` / `IOS` / `APP_STORE_ELIGIBLE`.

## Decisions taken

- ~~**Decision 1: offset the run number.** `BUILD_OFFSET=1000` in `ci_pre_xcodebuild.sh`.~~ **Reversed on
  2026-08-10 after run 3 disproved it.** No hook can set the build number that reaches App Store Connect;
  the offset now lives on `release.sh`'s side instead. See Phase 0 Decision 1.
- **Decision 2: gate in `ci_pre_xcodebuild.sh`.** It calls `scripts/verify-core-tests.sh`. No Xcode test target
  was added. Option 1 as recommended.
- **Decision 3: delivery to testers is a command, not a post-action.** Reversed on 2026-08-09 after the
  sibling project ran it both ways — the reasoning is in Phase 1 step 6, and it changes what the status
  report is allowed to warn about (Phase 7).
- **Shebang:** the hook is `#!/usr/bin/env bash` with `set -euo pipefail`, matching every other script in
  `scripts/`, rather than the `#!/bin/sh` in the Phase 3/4 drafts below.
- **Decision 4: the tester note is written over the API, not by a hook.** Taken 2026-08-10, after
  `ci_post_clone.sh` was built, shipped, and observed to be honoured on two runs out of five with no
  way to tell which. `scripts/testflight_distribute.py` owns it now and the hook is deleted — see
  Phase 4 and the tester-note risk.

## Goal

A push to `main` builds the iOS app on Apple's infrastructure and puts it on TestFlight, without
anyone running `scripts/ship-ios.sh`.

The point is **not** to save the typing. A local build compiles your working tree, so a commit can be
broken while every command on your machine is green. Xcode Cloud is the only thing that builds what
was actually pushed.

## Overview

```
push to main → Xcode Cloud workflow → Archive (scheme NoSpoilersApp) → build on TestFlight,
                                                                       attached to no group

    you, when a build is worth someone's attention:
      testflight_distribute --apply → group Internal → tester's phone
```

**The second line is not an oversight.** A build reaches nobody until it is put in a group, and
doing that automatically is a decision this task takes deliberately against — Phase 1 step 6.

`scripts/ship-ios.sh` stays. This runs alongside it: Xcode Cloud for continuous internal builds,
`release.sh` for versioned App Store submissions. The macOS app is **out of scope** — it ships via
Developer ID and Homebrew (Task 08) and must not be archived here.

---

## Phase 0: Two decisions to make before touching anything

These are the only parts of this task that are specific to this repo, and both will cost a rejected
upload if they are got wrong.

### Decision 1: the build number

`CURRENT_PROJECT_VERSION` was `8` when this decision was taken and `MARKETING_VERSION` `1.0.22`, both
maintained by `release.sh` off git tags. It now reads `10000` — the bump below is what changed it.

**App Store Connect accepts a version/build pair exactly once**, and refuses anything that repeats
it. Xcode Cloud exposes `CI_BUILD_NUMBER` — the run number — which starts at **1**. Stamping it
naively would try to upload build 1, 2, 3 for a marketing version that already has a build 8, and
every one of those is either a duplicate or arrives out of order.

Three ways out were considered, and **the first one cannot be built.** Kept here because it is the
obvious idea and the next person will have it too:

1. ~~**Offset the run number.** `CURRENT_PROJECT_VERSION = CI_BUILD_NUMBER + 1000` from
   `ci_pre_xcodebuild.sh`.~~ **Impossible.** See below.
2. **Give Xcode Cloud its own marketing version** (say `1.0.22-ci`) so the build-number space is
   separate. Cleaner in theory, more moving parts, and clutters the version list.
3. **Do not stamp at all.** Only viable if you never want two Xcode Cloud builds of the same version,
   which defeats the purpose.

#### Why no hook can set the build number

**Xcode Cloud rewrites `CFBundleVersion` to `CI_BUILD_NUMBER` when it exports the IPA** — after
`ci_pre_xcodebuild.sh`, and after the archive action. Measured on run 3, by pulling both artifacts:

| Stage | `CFBundleVersion` |
|---|---|
| `ci_pre_xcodebuild.sh` log | `1003 in all 6 configurations` |
| `ARCHIVE` artifact — app and widget | **1003** |
| `ARCHIVE_EXPORT` app-store IPA — app and widget | **3** |
| App Store Connect build record | **3** |

The rewrite is consistent across the app and its extension, so nothing is malformed — the stamp is
simply overwritten. A hook that runs before `xcodebuild` cannot win against a step that runs after it.
This is also why the sibling project never noticed: it stamps `CI_BUILD_NUMBER` exactly, so its stamp
and Apple's rewrite agree, and the rewrite is invisible.

Nor can the run number be moved out of the way. `GET/PATCH` probing of the API:

```
ciProducts   -> DELETE, GET_COLLECTION, GET_INSTANCE   (does not allow UPDATE)
ciBuildRuns  -> CREATE, GET_INSTANCE                   (does not allow UPDATE)
```

and no build-number attribute exists on `ciProducts` (`buildNumber`, `nextBuildNumber`,
`currentBuildNumber`, `latestBuildNumber`, `startingBuildNumber` are all rejected as invalid field
names). There is nothing to set.

#### What was done instead: put the offset on the other path

The reasoning behind option 1 was right and was applied to the wrong side. Nothing rewrites
`release.sh`'s build numbers — it archives and uploads locally — so **that** is the path that can hold
an offset:

- The committed `CURRENT_PROJECT_VERSION` was bumped once, `8` → **`10000`**. `release.sh` already does
  `CURRENT_BUILD + 1`, so it continues 10001, 10002, … with no script change.
- `ci_pre_xcodebuild.sh` stamps `CI_BUILD_NUMBER` **exactly**, matching what Apple will write anyway and
  matching the sibling project's hook. Xcode Cloud owns the low numbers, `release.sh` owns 10000+.

Two consequences worth carrying: a five-digit build number is ugly in App Store Connect, and build
numbers only ever increase, so this cannot be undone.

**Left behind by the failed approach:** iOS `1.0.22` now holds build `3` from run 3 alongside build `8`
from `release.sh`. Build 3 sorts below 8, and had the offset been left in place, run 8 would have
produced a duplicate `8` and been rejected. Nothing needs fixing — `1.0.22` will not be uploaded again —
but that is why the iOS build list for that version reads oddly.

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
   - **Distribution: internal testing** — but read the next paragraph before accepting it

   An archive action with no distribution audience produces an artifact and stops. That state is
   indistinguishable from success in every screen Apple shows you.

   **The audience is stamped into each build and cannot be changed afterwards.** A build uploaded as
   `INTERNAL_ONLY` can only ever go to internal groups; there is no promoting it later. Changing the
   workflow to `APP_STORE_ELIGIBLE` affects only builds archived *after* the change, and everything
   already on TestFlight stays internal forever. If there is any chance you will want testers outside
   the team — see Phase 7 — choose `APP_STORE_ELIGIBLE` now and save yourself a dead set of builds.
   It costs nothing: internal delivery works identically under either value.

5. ~~Create an internal tester group in App Store Connect **before the first build**, with
   *access to all builds* enabled.~~

   **Done.** Group `Internal`, id `e4840ac3-284b-4b6c-a41f-b400d6d0fac1`, on app `6761343835`
   (`pomocorp.NoSpoilers.NoSpoilersMac`), created over the API with `isInternalGroup: true` and
   `hasAccessToAllBuilds: true` — that flag can only be set at creation. Patching it afterwards returns
   `409 ENTITY_ERROR.ATTRIBUTE.NOT_ALLOWED`, and the only fix is to delete the group and make it again.

   **The group was created with no testers in it**, and that is worth stating because an empty group
   builds and delivers fine and reaches nobody — there is no error anywhere. It holds one tester now,
   at `INVITED`; see the verification section for what that state does and does not prove.

   Adding one is two steps, and the first has a cost worth understanding:

   1. **Users and Access → +**, their email, and a role. An internal tester **must be an App Store
      Connect user on your team**, so this hands them a login to the developer account, not just the
      app. Only Account Holder, Admin, App Manager, Developer and Marketing are eligible as testers —
      **Marketing is the least privileged of those**, and unlike Developer it cannot upload builds or
      touch certificates. Scope them to this app while you are on that screen. If someone does not
      appear in the eligible list at step 2, their role is why.
   2. **TestFlight → Internal Testing → the group → Invite Testers**, tick them, Add.

   Limits: 100 internal testers, 30 devices each, no review, and the 90-day build expiry below.

   **`hasAccessToAllBuilds` does not attach Xcode Cloud builds to the group.** Apple's
   documentation says builds created by Xcode Cloud must be added to groups by hand, and on
   2026-08-09 that turned out to be true even for a group created with the flag set. Three VALID
   builds sat on TestFlight for a day reading `internalBuildState: READY_FOR_BETA_TESTING`, the
   group read `hasAccessToAllBuilds: true`, and nobody could install anything. The flag is
   necessary and not sufficient.

   Two things make it hard to see, and both look like success:

   - `GET /v1/betaGroups/{id}/builds` returns an empty list either way, so it distinguishes
     nothing. The query that answers it is `GET /v1/builds/{id}?include=betaGroups` — an empty
     `included` array means the build belongs to no group and no tester will ever see it.
   - The tester sits at `state: NOT_INVITED` and no invitation is ever sent, because there is
     nothing to invite them to. Trying to force one returns
     `409 STATE_ERROR.TESTER_INVITE.NO_INSTALLABLE_BUILDS`, *"Tester has no installable build"* —
     which is the clearest diagnostic in this whole API and only appears if you go looking.

   The fix is one `POST /v1/betaGroups/{id}/relationships/builds` with `{"data": [{"type":
   "builds", "id": "<build>"}]}`, answering `204`. **Pending invitations then send themselves** —
   the tester flipped `NOT_INVITED` → `INVITED` on the next read with no second call.

6. **Do not automate the hand-over. Make it a command you run.**

   There is a post-action that would do it — App Store Connect → the app → **Xcode Cloud** →
   **Manage Workflows** → the workflow → **Post-Actions** → **+** → *TestFlight Internal
   Testing* → add the group. Xcode Cloud then waits for processing and attaches each build
   itself, with the archive action's distribution audience as the only prerequisite. The sibling
   project set one up, ran on it for a day, and took it back out. Two reasons, and the second is
   the serious one:

   **Every push would notify every tester.** With agents and more than one session pushing, that
   is several builds a day. A tester who has learned to ignore the notification is worse than no
   automation at all, and the notification is the entire value of the feature. Builds cost
   nothing accumulating in App Store Connect, so the cheap thing to defer is the delivery, not
   the build.

   **It cannot be verified, restored, or even seen.** `ciWorkflows` carries no post-action field
   and `betaGroups` is not a valid relationship on it, so a post-action cannot be created, read
   back, diffed, or restored from a script, and its absence cannot be detected. A workflow dump
   that looks complete is not a complete workflow. On the sibling project it was added, reported
   as added, and **never once observed to fire**: build 24 still needed the manual command after
   it was set, build 25 went `VALID` with testers left on 24, and the workflow editor later read
   *"No post-actions have been added."* Whether it never saved, or came off with an unrelated
   edit, is unknowable from outside — which is exactly the objection. Do not build a delivery
   story on a mechanism with no read path.

   So: **push archives, a command distributes.** Phase 7 has the command. One consequence to
   carry forward — the newest build now sits in no group as a matter of course, which changes
   what your status report is allowed to warn about.

   The same reasoning rules out an external post-action, with an extra edge: feeding the public
   link automatically means every push proposes itself to strangers, and the first build of each
   marketing version sits in Beta App Review regardless.

### What Xcode actually generated, and why steps 2 and 4 above are not optional

Create Workflow produced **two** archive actions, not one, and gave neither an audience:

```
ARCHIVE | scheme NoSpoilers    | MACOS | buildDistributionAudience: null
ARCHIVE | scheme NoSpoilersApp | IOS   | buildDistributionAudience: null
```

So it archived the Mac app this task says must not be archived here, and produced the
artifact-and-stop state step 4 warns about. Runs 1 and 2 both went `SUCCEEDED` and delivered
nothing; App Store Connect stayed on build 8 throughout. Fixed with a single call:

```
PATCH /v1/ciWorkflows/6EE7E8AE-43B3-4A88-94AB-729C6EE45E6B
  attributes.actions = [ one ARCHIVE, NoSpoilersApp, IOS, APP_STORE_ELIGIBLE ]
```

**A run snapshots the workflow when it starts.** Run 2 began 90 seconds before the patch and still
carried the macOS action. Patching mid-flight changes nothing already queued.

### When Xcode will not let you create the workflow

Two symptoms, one cause, and an hour lost to it:

- **Integrate → Manage Workflows greyed out**, and
- **Create Workflow refusing with "a workflow with that name already exists".**

They look contradictory — nothing to manage, yet something already exists — and they are the same
fault. Xcode *lists* products to populate its menu, and `GET /v1/ciProducts` was returning
`total: 0` while individual products still resolved by id. Create validates against the server,
which had them. Xcode was reading an empty list and a non-empty server.

The cause was a product in a broken state: `EDF20772-21CF-443B-9337-464D47B3F61F`, which belonged
to a sibling project, had been renamed `NoSpoilersApp`, had this repo attached as its primary
repository, and had **lost its `app` relationship entirely** — `relationships/app` returns
`{"type": "apps"}` with no id and `GET …/app` returns a 500. A product with no app does not
enumerate, and one unlistable product appears to make the whole list unlistable.

What did not help, in case it is tempting:

- **Clearing `~/Library/Developer/Xcode/UserData/XcodeCloud/`.** The cache was empty *because* the
  list was empty; Xcode rebuilt it and it was empty again. Phase 6 already says that sqlite is a
  cache and not a record — it is equally useless as a lever.
- **The App Store Connect UI**, which showed the onboarding splash for this app and no product at
  all. That screen is worth checking precisely because it is unambiguous: it means no product, not
  a hidden one.

What did work was retrying Create Workflow in Xcode later, which made a **new** product
(`1F3A0BBD-…`, properly attached to app `6761343835`) and left the broken one in place. So: if the
list is empty and the dialog says otherwise, look for an orphaned product by id before touching
anything local.

**Still outstanding:** `EDF20772-…` is orphaned and still holds the sibling project's `Default`
workflow (`6229CF74-F464-4EF7-A6AE-64C7B8A21279`). That project keeps shipping — uploads go by
bundle id, not by the product's app link — but its Xcode Cloud tab is presumably as empty as this
one's was. `ciProducts` has no `PATCH`, so the only repair is `DELETE`, which takes its workflow and
build history with it. Recorded here so that is recoverable rather than irreversible:

```
repository        npomfret/super-funmax-music  (3706b1f0-bfe2-472b-b936-b24b6043d789)
containerFilePath apple/FunMaxMusic/FunMaxMusic.xcodeproj
branch            main, autoCancel true, clean true
action 1  TEST     scheme FunMaxMusic, IOS, ANY_IOS_SIMULATOR, isRequiredToPass true
                   SPECIFIC_TEST_PLANS "UnitTests", iPhone 17 Pro / iOS 26.5 simulator
action 2  ARCHIVE  scheme FunMaxMusic, IOS, APP_STORE_ELIGIBLE, isRequiredToPass true
```

---

## Phase 2: Where the CI scripts go — DONE

The hook lives in `NoSpoilers/ci_scripts/` — **beside `NoSpoilers.xcodeproj`, not at the repository
root.**

```
no-spoilers/
  NoSpoilers/
    NoSpoilers.xcodeproj
    ci_scripts/            <- here
```

Putting it at the repository root produces no error at all — just nothing happening. It must be
committed executable (`chmod +x`).

**`NoSpoilers/TestFlight/` no longer exists**, and neither does its `.gitignore` entry. It held the
*What to Test* note, which is now written over the API by `scripts/testflight_distribute.py` — see
Phase 4 and the tester-note risk. The directory is still where Apple would look for such a file if
anyone reinstates the mechanism, which is why the path is recorded rather than forgotten.

---

## Phase 3: `ci_scripts/ci_pre_xcodebuild.sh` — DONE

Written to `NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh`, mode `755`. That file is authoritative; the draft
that was here has been removed rather than left to drift out of sync with it.

Two changes from the draft:

- **It checks every configuration, not the first.** `grep -q` passes as soon as one line matches, which is
  satisfied by a partial stamp — and a partial stamp is exactly the app/extension build-number mismatch that
  gets an upload rejected. The script now compares the count of `CURRENT_PROJECT_VERSION = ` lines against the
  count carrying the new value, and fails unless they are equal. There are 6.
- **`agvtool` prints `Cannot find ".../YES"`**, which is it misreading `GENERATE_INFOPLIST_FILE = YES` as a
  plist path. Observed on this project; harmless, exit status unaffected. The script says so, so nobody
  spends an afternoon on it.

Notes:

- `agvtool new-version -all` updates **every** build configuration, which is what you want here:
  `NoSpoilersWidgetExtension` has its own `CURRENT_PROJECT_VERSION` and an app whose extension
  disagrees about its build number is rejected at upload.
- It is idempotent and exits 0 when the value is already set, so running it twice in a run is fine.
- It also writes `CFBundleVersion` into any `INFOPLIST_FILE` it finds. Redundant, and harmless — the
  checkout is thrown away with the run.
- `verify-core-tests.sh` writes into `tmp/` under the repo root and sets its own `HOME`. **Checked** against
  a fresh `git clone` of this repo: 8 tests, build and run clean, nothing outside the checkout needed.

### If this step fails

The log for it is inside the action's `LOG_BUNDLE` artifact, as `ci_pre_xcodebuild.log`. See Phase 6.

---

## Phase 4: `ci_scripts/ci_post_clone.sh` — BUILT, THEN DELETED

It existed, it worked, and it was removed on 2026-08-10. It wrote the TestFlight *What to Test* note
from the commit being built, into `NoSpoilers/TestFlight/WhatToTest.en-GB.txt`, and every run logged
it doing so correctly. **App Store Connect read that file on some runs and not others** — the table
under the tester-note risk below has the measurements — and no artifact Apple exposes says which.

`scripts/testflight_distribute.py` now writes the note over the API, so the hook was the second
implementation of a job already owned elsewhere, and the less reliable of the two. Deleted rather
than kept as a fallback: a fallback that silently disagrees with the primary is how the stale note
survived four builds without anyone noticing.

What it cost to run it, kept because the rules are not obvious and apply to any future
`ci_post_clone.sh`:

- **A non-zero `ci_post_clone.sh` fails the entire run**, not just one action — the opposite of
  `ci_pre_xcodebuild.sh`. Every path in it ended at `exit 0`, because no missing tester note is worth
  a failed delivery, and it deliberately did not carry the repo-standard `set -euo pipefail`. Never
  put the test gate in this hook.
- It checked `CI_PRIMARY_REPOSITORY_PATH` explicitly rather than leaning on `mkdir -p` failing.
  Unset, it would otherwise have tried to create `/NoSpoilers/TestFlight` at the filesystem root and
  reported nothing about why the note was missing.

The surviving hook echoes on success deliberately. An empty log is indistinguishable from a script
that never ran, and that ambiguity cost a diagnosis on the project this came from.

---

## Phase 5: What is already correct in this repo

Checked against the working tree, so you do not go looking:

| Thing | State | Why it matters |
|---|---|---|
| `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` | **set** on the app configurations | Without it every build arrives as *Missing Compliance* and testers cannot install it until somebody answers by hand, per build |
| iOS app icon | **1024×1024, no alpha** | An icon set that declares its slots and holds no image files compiles cleanly and is refused at upload with a single unexplained line. The primary icon is present, so this trap does not apply here |
| Dark / tinted icon slots | declared, no files | Not a failure — iOS generates them. Supply real ones if you care how they look |
| App Store Connect API key | `AuthKey_S394C74APG.p8`, issuer `69a6de6e-…` | Already used by `ship-ios.sh` and proven — but it is a **Developer**-level key. Enough for everything in Phases 1–6; not enough for Phase 7. See below |
| Signing | automatic, team `6FZN56WC8G` | Xcode Cloud manages its own certificates; `ExportOptions-AppStore.plist` is not used by it |
| App Store Connect record | app `6761343835`, iOS `1.0.22` held build **8** before this task | The number `release.sh` had reached, and what the committed bump to `10000` had to clear |
| Xcode Cloud product | **exists**, `1F3A0BBD-…` | Created 2026-08-10 from Xcode. The API cannot create one, so this part of Phase 1 can only happen there — everything after it can be done over the API |

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

Three endpoint shapes that waste a round trip each:

- `GET /v1/builds/{id}/betaGroups` is **forbidden** — the relationship allows `CREATE` and `DELETE`
  only, and `GET /v1/builds/{id}/buildBundles` is closed the same way: *"has no allowed operations
  defined"*. Do not go the other way round to compensate. `GET /v1/betaGroups/{id}/builds` answers
  an empty list for an internal group whether or not the build is in it, so it looks like a working
  substitute and is not one. The only query that separates the two cases is `GET
  /v1/builds/{id}?include=betaGroups` — an *include* on the build, not the forbidden relationship.
- `GET /v1/apps/{id}/builds` rejects `sort` outright with `PARAMETER_ERROR.ILLEGAL`, unlike
  `buildRuns`, which requires it. Neither behaviour is guessable from the other.
- A build carries no link back to the run that produced it. The only direction that works is
  `GET /v1/ciBuildRuns/{id}/builds`, and that relationship includes builds whose upload failed and
  which no tester ever saw — intersect it with the app's real TestFlight builds before believing it.

---

## Phase 7: External testers — people without an App Store Connect account

Only needed if you want the app on the phone of someone you will not add to the team. Internal
testing (Phase 1, step 5) is simpler and has no review; do not take this on unless you need it.

**What it buys:** up to 10,000 testers, invited by email or by a **public link** they simply tap —
no account, nothing to administer per person.

**What it costs:** the first build of *each marketing version* goes through Beta App Review, days
rather than hours at the moment. Bump `MARKETING_VERSION` and you are back in the queue. Only 6
builds per 24 hours may be submitted, and only one build per version can be in review at a time.

### Prerequisites, in the order they bite

1. **The archive action must be `APP_STORE_ELIGIBLE`**, and only builds archived after that change
   qualify. See Phase 1, step 4. Get this wrong and the fix is not a setting, it is a new build.
2. **An internal group must exist first.** Apple requires it before an external group can be created.
3. **Test Information** on the app record: a beta app description and a **feedback email**. External
   testing is blocked without it.
4. Export compliance already answered — `ITSAppUsesNonExemptEncryption` is set here (Phase 5).

### Do this part in the App Store Connect UI, not the API

Confirmed the hard way on the project this came from, with a key that was demonstrably not read-only
— it had just rewritten a workflow, and it created and deleted an internal group cleanly in the same
session:

| Request | Result |
|---|---|
| `POST /v1/betaGroups` with `isInternalGroup: true` | **201** |
| `POST /v1/betaGroups` with `isInternalGroup: false` | **403**, `title` "Unable to process request.", `detail` empty |
| `POST /v1/betaAppLocalizations` (the feedback email) | **403**, "The API key in use does not allow this request" |

The second message names the cause the first one hides: **an App Store Connect API key at Developer
level can manage Xcode Cloud and internal TestFlight, but not app metadata and not external
distribution.** `AuthKey_S394C74APG` — the key this repo already uses — is one of those, so this
applies here directly.

A bare 403 with an empty `detail` from this API is worth reading as "your key is not allowed to do
this", not "your request was malformed" — the two are indistinguishable from the response alone, and
the empty one will send you rewriting a body that was fine.

**A team key with the App Manager role already exists: `ASC6H3SL2D`**, created 2026-08-09 on team
`6FZN56WC8G`, private key at `~/.appstoreconnect/private_keys/AuthKey_ASC6H3SL2D.p8`. Team keys are
not per-app, so it works against this app record too. Use it as a *second* credential rather than
replacing `S394C74APG`: the release path keeps the smaller key, and only the command that
distributes builds gets the larger one.

### The step nobody tells you about

**A build reaches no group of any kind until it is put there.** This is the single fact this
document got wrong for longest — see Phase 1 step 5 — and it applies to the internal group as
much as the external one. `hasAccessToAllBuilds` governs which builds a tester *may* see, not
which builds exist for them, and an Xcode Cloud archive lands attached to nothing:

```
POST /v1/betaGroups/{group}/relationships/builds
     {"data": [{"type": "builds", "id": "<build>"}]}          -> 204
```

For an internal group that is the whole procedure, and any pending invitation sends itself
immediately afterwards. For an external group the first build of each marketing version must also
be submitted:

```
POST /v1/betaAppReviewSubmissions
     {"data": {"type": "betaAppReviewSubmissions",
               "relationships": {"build": {"data": {"type": "builds", "id": "<build>"}}}}}
```

**Xcode Cloud does neither.** Nothing reports the gap: the run is green, the build is `VALID`,
`internalBuildState` reads `READY_FOR_BETA_TESTING`, and every tester has nothing. A post-action
would do it, and Phase 1 step 6 is the argument for not using one.

So this is a command, and it is the whole delivery step. **Built: `scripts/testflight_distribute.py`.**
Dry-run by default, `--apply` to add the newest build, `--apply --submit` to send it for review as
well. **It touches internal groups only unless `--group` names one** — reaching a public link should
cost you the effort of typing its name, so that no future change to a default can publish something
on your behalf.

Adapted from the sibling's version rather than copied, because two things here are different and
both are silent failures:

- **The app record holds macOS and iOS**, so an unfiltered build list interleaves them and the
  newest upload is as likely to be a Mac build. Every query filters on
  `filter[preReleaseVersion.platform]=IOS`. Measured: the unfiltered list returns 8 builds, the
  filtered one 4.
- **Newest is by `uploadedDate`, not by build number.** The sibling sorts numerically because it has
  one upload path. Decision 1 gave this repo two deliberately separate bands, so the highest number
  is routinely the *older* build — after the next `release.sh` run, numeric sorting would pin
  testers to `10001` and never offer them a CI build again. Both directions are in the selftest.

Keep it separate from whatever reads state. One script writes to App Store Connect, one only
issues `GET`s, and that split is what makes the report safe to run whenever the answer is in
doubt. It is also a real boundary: the read-only script runs on a Developer key, and only the
distributing one is given the App Manager key.

### What the status report should say, once delivery is manual — BUILT

This is the trap in the change. With no post-action, **the newest build is in no group as a matter
of course**, so a "newest `VALID` build reaches nobody" warning fires after every single push. A
warning that is always on is the same as no warning, and it takes the exit code with it.

Report the useful fact instead — **which build the testers can actually install, and how far
behind the newest it has fallen** — and warn only when they can install *nothing at all*, which is
the genuine failure. `scripts/appstore_status.py` now prints it:

```
TESTFLIGHT (IOS)
  tester group        Internal (internal)   1 tester
  newest build        11
  testers can install build 4, 5 builds behind build 11
```

Five builds behind and **nothing under NEEDS YOU**, which is the whole design: that gap is the
normal state of a repo whose delivery is a command, and the exit code stays 0 for it. After the
command runs, the same line reads `testers can install build 12 — the newest`, so the report says
which of the two states you are in without ever making the ordinary one look like a fault. The four ways
of reaching "nothing at all" — no group, every group empty, every build expired, no build in any
group — each warn with their own line, because the fix differs in each case.

**Both readings have now been observed on the real account, twelve minutes apart.** Distributing
build 12 moved the line to `testers can install build 12 — the newest`; the next push produced run
13 (`SUCCEEDED` on `7fec1d7`, build 13 `VALID`, `betaGroups` empty) and the line went to
`testers can install build 12, 1 build behind build 13` on its own, with NEEDS YOU untouched. That
is the cycle this section was written for, and it is now the observed default rather than the
predicted one: **every push puts the report into the behind-state, and it stays quiet about it.**

There is no cheap query for it. It walks the unexpired builds newest-first, asking each one `GET
/v1/builds/{id}?include=betaGroups` until one comes back with a non-empty `included`, and stops
after ten (`DISTRIBUTION_WALK`). That is one request per undistributed build, which is the price of
the group's own build list being useless.

**The build-selection helpers moved into `appstore_status.py` to build this** — `builds_path`,
`platform_builds`, `live_builds`, `newest_build`, `groups_holding`, and the `IOS` constant.
`testflight_distribute.py` imports them rather than keeping its own copies. The import direction
only goes one way, so the shared code has to live in the report; and the report and the command
must agree about which build is newest or they contradict each other in the same terminal. Their
selftests moved with them: 52 cases in the report, 25 in the command.

Ask a build which of these applies with `GET /v1/builds/{id}/buildBetaDetail`. Its
`externalBuildState` is the only field that answers honestly, and
**`NOT_APPLICABLE` is the marker for a build archived `INTERNAL_ONLY`** — the one state no retry,
setting, or resubmission will move. `READY_FOR_BETA_SUBMISSION` means it needs review;
`READY_FOR_BETA_TESTING` means it is approved and can simply be handed over.

### The public link

Created per external group, optionally capped at a tester count. **Set a limit.** Unlimited is the
setting you cannot walk back once the URL is out of your hands, and a public link cannot be
un-shared — only disabled, after the fact.

The link distributes nothing until a build passes review, so it is safe to create early.

---

## Verification

### Already proven locally

Both hooks were run against a fresh `git clone` of this repo with `CI_PRIMARY_REPOSITORY_PATH`,
`CI_BUILD_NUMBER` and `CI_COMMIT` set by hand, which is the whole of their contract with Xcode Cloud:

- [x] ~~`ci_post_clone.sh` writes `WhatToTest.en-GB.txt` containing the commit subject, build number
      and 12-character hash. Exit 0.~~ Held, and irrelevant: the script was deleted on 2026-08-10.
      It is left here because it is the point — **the hook was never the thing that was broken**, and
      proving it worked proved nothing about whether the note arrived.
- [x] `ci_pre_xcodebuild.sh` end to end: 8 core tests pass, then all 6 `CURRENT_PROJECT_VERSION`
      occurrences move to `1007` for `CI_BUILD_NUMBER=7`. Exit 0.
- [x] **The gate holds.** With a deliberately failing test added to `NoSpoilersCore`, the script exits **1**
      at the test step and the build number is never stamped. This is the mechanism the Decision 2
      checkbox below depends on; what remains unproven locally is only that Xcode Cloud honours a non-zero
      pre-build hook, which needs the real push.
- [x] Guard paths: no `CI_PRIMARY_REPOSITORY_PATH` → exit 0 with a reason logged, in both scripts.
      No `CI_BUILD_NUMBER` → exit 1.
- [x] `verify-core-tests.sh` needs nothing outside the checkout — the clean-runner risk below is closed.
- [x] `agvtool` reaches all 6 configurations on this project, including the widget extension's own two.

### Proven on Xcode Cloud — run 1, 2026-08-10, commit `f0b248f`

Read out of the run's `LOG_BUNDLE` artifact, which is where the hook logs live:

```
ci_post_clone: writing /Volumes/workspace/repository/NoSpoilers/TestFlight/WhatToTest.en-GB.txt
add Xcode Cloud CI hooks for the iOS TestFlight path

Build 1 from f0b248f29170

ci_pre_xcodebuild: run 1, commit f0b248f2917046c9419b718bc0af8f4410ee7884
ci_pre_xcodebuild: running scripts/verify-core-tests.sh
ci_pre_xcodebuild: core tests passed
ci_pre_xcodebuild: CURRENT_PROJECT_VERSION is now 1001 in all 6 configurations
```

- [x] **`verify-core-tests.sh` runs on a clean Xcode Cloud runner.** 8 tests, 0 failures. It creates
      `tmp/` and overrides `HOME` under `/Volumes/workspace/repository` without complaint. This was the
      largest open risk in this file and it is now closed on the real thing, not a local proxy.
- [x] **The offset works.** `CI_BUILD_NUMBER=1` → `1001`, in all 6 configurations.
- [x] **`ci_post_clone.sh` works on the runner**, writing the note under the Xcode-Cloud checkout
      path. It did this on every run and the note still went missing on three of them, which is why
      the script no longer exists.
- [x] **The hook ran once, not once per `xcodebuild`.** One `ci_pre_xcodebuild: run 1` line in the whole
      log. The compute worry recorded below was overstated.

Not proven by these runs, and worth being precise about: both had **no distribution audience**, so
nothing was ever going to be uploaded. A green run here says the scripts work. It says nothing about
delivery, and nothing about the gate — a passing test cannot demonstrate that a failing one stops
anything.

### Proven on Xcode Cloud — run 4, 2026-08-10, commit `0c3bd32`

The first run with the offset removed, and the one that closes Decision 1. From the `LOG_BUNDLE`:

```
ci_pre_xcodebuild: run 4, commit 0c3bd3298aef1e45601e597e2bd1bfec516afea6
ci_pre_xcodebuild: running scripts/verify-core-tests.sh
ci_pre_xcodebuild: core tests passed
ci_pre_xcodebuild: CURRENT_PROJECT_VERSION is now 4 in all 6 configurations
```

- [x] **The archive and the upload finally agree.** `CFBundleVersion` reads `4` in the `xcarchive`
      (app, widget extension, both dSYMs) and `4` in the exported `app-store` IPA (app and widget).
      Run 3's `1003`-vs-`3` split is gone.
- [x] **App Store Connect recorded build `4`**, `VALID`, `APP_STORE_ELIGIBLE`, against pre-release
      version `1.0.22`, with `betaGroups` empty.
- [x] **Apple's rewrite is visible in the export options**, which is worth knowing when this next
      surprises somebody: the distribution log opens with
      `"manageAppVersionAndBuildNumber":false, ... "buildNumber":"4"`. Xcode Cloud passes the run
      number into the export regardless of what the project says. The stamp's only job is to make
      the archive match it.

### Proven on Xcode Cloud — run 8, 2026-08-10, commit `afbedaf`

**The gate.** A test was broken on purpose (`GateProofTests.swift`, one `XCTFail`), pushed to `main`,
and reverted in the next commit. This is the run Decision 2 rests on, and it had never been done.

```
ci_pre_xcodebuild: run 8, commit afbedaf98448ce484275d4bf7deec4d077d81c3d
ci_pre_xcodebuild: running scripts/verify-core-tests.sh
...
GateProofTests.swift:18: error: ... failed - deliberate failure
	 Executed 9 tests, with 1 failure (0 unexpected)
```

- [x] **The run failed and nothing was delivered.** `completionStatus FAILED`, and the archive
      action carries exactly one non-warning issue: `ShellScriptStep | Running ci_pre_xcodebuild.sh
      script failed (exited with code 1)`. The iOS build list was 3, 4, 5, 6 before the push and 3,
      4, 5, 6 after it.
- [x] **The log stops where it should.** It ends on the test output — no `core tests passed`, no
      `CURRENT_PROJECT_VERSION is now 8`. The gate fires before the stamp, so a red commit never
      even reaches `agvtool`.
- [x] **No archive was produced at all.** The action's only artifact is a `LOG_BUNDLE`. Runs that
      deliver carry `ARCHIVE` and `ARCHIVE_EXPORT` beside it, so their absence is a second,
      independent reading of the same fact.

The revert went out as run 9, commit `43c3b08`, and closes the other half: **a clean commit still
delivers.** `SUCCEEDED`, build `9` `VALID`, `betaGroups` empty as always. A gate that stops everything
is not a gate, and the pair of runs is what distinguishes the two.

Two things run 8 exposed that were not what it was testing:

- **`autoCancel` burns run numbers.** The push carried two commits, so `f58634f` started run 7 and
  `afbedaf` immediately cancelled it. `CANCELED` runs consume a number exactly as failed ones do —
  the numbering is per product, not per delivered build, and it is why the break landed on run 8
  rather than run 7. A number is not a promise that a build exists.
- **Run 8 was heading for a duplicate anyway.** iOS `1.0.22` already holds build `8`, uploaded by
  `release.sh` on 2026-05-01 and now expired — see the note in Decision 1. Had the tests passed,
  the upload would have been rejected for repeating a version/build pair, and the run would have
  failed for a reason with nothing to do with the gate. It did not happen, but only by luck of
  ordering. **Expired builds still occupy their number**, and run 9 onward clears it only because
  `9 > 8`; a `MARKETING_VERSION` that stays on `1.0.22` while the run counter walks up is safe from
  here, but this is the collision the `10000` bump does not protect against, because the bump only
  moves *future* `release.sh` builds.

### Still needs a real run

- [x] A push to `main` produces a run that reaches `SUCCEEDED`. Run 2, `GIT_REF_CHANGE` on `9399175`.
- [x] The build appears in TestFlight as `VALID`, not *Missing Compliance*. Run 3's build reads
      `processingState VALID`, `usesNonExemptEncryption False`, `internalBuildState
      READY_FOR_BETA_TESTING`, `externalBuildState READY_FOR_BETA_SUBMISSION`,
      `buildAudienceType APP_STORE_ELIGIBLE`.
- [x] **The build reaches no group on its own.** `GET /v1/builds/{id}?include=betaGroups` came back
      with `included: 0` after run 3 — Decision 3 behaving as designed.
- [x] **A tester can actually install it after the distribute command.** **Closed 2026-08-10: build
      13 was installed on a phone and launched.** That is the whole chain — push, archive, gate,
      upload, `--apply`, a person tapping Install — done end to end on one commit (`7fec1d7`), and
      it is the only checkbox in this file that no API call could ever have ticked.

      How it read before that, kept because the intermediate state is the one that misleads:
      `scripts/testflight_distribute.py --apply` put build 4 in `Internal`, and
      `GET /v1/builds/{id}?include=betaGroups` now names the group where it returned an empty
      `included` before. Re-running says "already there" and writes nothing. **What is still
      unproven is the install itself.** The invitation half is now closed: a tester was added to
      `Internal` and reads `state: INVITED`, `inviteType: EMAIL`, without anything calling
      `betaTesterInvitations` — **adding the build sent it**, exactly as this file predicted, and
      the `NO_INSTALLABLE_BUILDS` refusal of 2026-08-09 cannot recur while a build is in the group.
      What remains is a person opening TestFlight and the app launching. `VALID` proves nothing
      about that. Note `state` reads are eventually consistent and can flip back briefly.
- [x] **A tester who has not redeemed the invite still sees "no builds available."** ~~Check
      `appDevices` on the tester: an empty array means the code was never redeemed on a device.~~
      **`appDevices` does not mean that, and this file said it did.** The tester read `state
      INSTALLED` with `appDevices []` — stable across three consecutive reads — on a phone that had
      just installed build 13. So an empty `appDevices` is compatible with a redeemed invitation
      *and* an installed build, and using it as the redemption test gives a false negative on a
      tester who is demonstrably fine.

      **`state` is the field that answered.** It moved `NOT_INVITED` → `INVITED` → `INSTALLED`
      across the three things that actually happened: the build reaching the group, the invitation
      being redeemed, the app being installed. `appDevices` never moved at all. Read `state`, and
      treat `appDevices` as telling you nothing either way.

      **Ask the group, not the tester.** `GET /v1/betaGroups/{id}/betaTesters` populates `state` and
      `appDevices`; `GET /v1/betaTesters/{id}` returns **`None` for both** on the same tester in the
      same second, and `GET /v1/betaTesters/{id}/appDevices` is a flat `404` — that relationship
      does not exist. The obvious query is the one that answers `None`, and `None` reads exactly
      like "no devices", so the instinctive route gives you the right diagnosis by accident and the
      wrong one just as easily.

      ~~Current reading, 2026-08-10: `state INVITED`, `appDevices []`. **The invitation has never
      been redeemed on a device.**~~ That inference was drawn from `appDevices` and it was wrong in
      the one direction that matters — it declared a working setup broken. The `INVITED` reading was
      correct at the time; the reason attached to it was not.
- [x] ~~Its build number is `CI_BUILD_NUMBER + 1000`~~ — **disproved on run 3**, and the reason is now
      Phase 0 Decision 1. The uploaded build number is `CI_BUILD_NUMBER`, and no hook can change that.
- [ ] After the `10000` bump: a `release.sh` iOS upload lands at `10001` and an Xcode Cloud run lands at
      its run number, with no collision. **Not yet exercised — `release.sh` has not run since the bump.**
- [x] The widget extension's build number matches the app's. Both `1003` in the run 3 archive and both
      `3` in the uploaded IPA — Apple's rewrite covers the extension too, and both read `4` on run 4.
- [x] *What to Test* in TestFlight shows the commit subject and short hash. Apple's own pickup is
      **intermittent** — it worked on runs 3 and 9, failed on runs 4, 5 and 6 — and is no longer
      relied on: `testflight_distribute.py` writes the note itself. See the open risk below.
- [x] Breaking a `NoSpoilersCore` test and pushing produces a **failed run and no new TestFlight
      build**. Done on run 8 with a deliberate `XCTFail`, reverted immediately afterwards. Decision 2
      is no longer a claim — see the run 8 section above for the evidence and for two hazards it
      turned up on the way.
- [ ] `scripts/ship-ios.sh` still works afterwards and does not collide with a CI build number.

---

## Open risks

- ~~**`verify-core-tests.sh` on a clean runner.**~~ Closed on run 1: 8 tests, 0 failures, on Apple's
  hardware.
- ~~**The hook runs before every `xcodebuild` invocation**, so the core tests may run more than once
  per build.~~ Did not happen: one invocation per archive action in run 1. Left unmitigated, and a skip
  marker is still the wrong fix — it would be another way for the gate to disappear silently.
- **Compute allowance.** Archiving on every push spends against 25 hours a month that do not roll
  over. If `main` is busy, move the start condition to a tag or manual trigger. Adding the core tests
  to every build makes each run longer. Note that runs 1 and 2 fired 2 minutes apart, one manual and
  one on the push, and both archived macOS as well — three archives' worth of allowance for nothing.
- **The workflow is editable from three places and readable from one.** Xcode, the App Store Connect
  UI, and `PATCH /v1/ciWorkflows` all write it; nothing in this repo pins it. What Xcode generated
  (two archive actions, no audience) was wrong on both counts against this file, and a later edit in
  any of the three could put it back with no signal. `GET /v1/ciWorkflows/{id}` is the only way to
  know what it currently says.
- **The tester note is intermittent, which is worse than broken.** Every build's note, read from
  `GET /v1/builds/{id}/betaBuildLocalizations`:

  | Build | `whatsNew` |
  |---|---|
  | 3 | `task update` / `Build 3 from e762f5c7d8d7` — its own |
  | 4 | `task update` / `Build 3 from e762f5c7d8d7` — **run 3's** |
  | 5 | `task update` / `Build 3 from e762f5c7d8d7` — **run 3's** |
  | 6 | `task update` / `Build 3 from e762f5c7d8d7` — **run 3's** |
  | 9 | `revert the deliberate test break…` / `Build 9 from 43c3b08b2f93` — its own |
  | 10 | `make the distribute command own…` / `Build 10 from 7b50e5a24983` — its own |
  | 11 | **empty** — the first run with no `ci_post_clone.sh` |
  | 12 | `report which build the testers…` / `Build 12 from 033ed528c33f` — written by the API |
  | 13 | arrived **empty**, then `record build 12: the note's…` / `Build 13 from 7fec1d7f88e7` |

  Every one of those runs logged `ci_post_clone` writing the file with its own subject and hash, so
  the hook is not the variable. Not eventual consistency either: build 4 was polled twelve times over
  30 minutes and never changed, and build 6 still reads run 3's note days-old at the time of writing.

  **The earlier reading of this — "picked up once on run 3 and never again" — was wrong**, and it was
  wrong in the direction that stops you looking: a mechanism that has failed permanently gets
  written off, and one that works three runs in six has to be explained.

  ~~Run 9 is also the first run after a *failed* run, which is the only difference anyone has
  spotted.~~ **Dead.** Run 10 followed run 9, which succeeded, and picked its note up anyway.

  **Build 11 is the control, and it came out as predicted.** It is the first run with the hook
  deleted, and its note is not stale — it is *empty*, and the distribute script said so rather than
  reporting a previous build's text. So Apple was reading the hook's
  file all along, on the runs where it worked, and nothing else was ever writing one. The
  intermittency was in the pickup, not in the writing, which is what every other reading of the
  evidence already said and is now confirmed from the other direction.

  **Empty, not absent — and the difference matters to the code.** Every Xcode Cloud build here
  carries exactly one `en-GB` `betaBuildLocalization`; on an undistributed build its `whatsNew` is
  `null`. Build 11 still reads that way, and build 13 did until it was distributed — neither had
  been touched by the script when they were read, so Apple creates the localization and leaves it
  blank. The two expired `release.sh` uploads — build 8
  on `1.0.22` and build 6 on `1.0.21` — carry **no** localization at all, so this is something the
  Xcode Cloud upload path does, not something every build gets.

  (That is also why the iOS build list appears to hold two build 6s. They are on different marketing
  versions, so nothing collides; a build number is only unique within its version.)

  **Two explanations have been checked and both are wrong.** Record them so they are not tried again:

  - ~~The notes belong at the repository root, not beside the `.xcodeproj`.~~ **No.** The sibling
    project on this same team writes them beside its project — `apple/FunMaxMusic/TestFlight/`,
    against container `apple/FunMaxMusic/FunMaxMusic.xcodeproj`, gitignored exactly as here — and
    its notes work. This repo's layout is the same shape and the workflow container confirms it:
    `NoSpoilers/NoSpoilers.xcodeproj` beside `NoSpoilers/TestFlight/`. The path is right.
  - ~~App Store Connect carries the previous note forward for builds of the same version, so this is
    Apple's behaviour rather than a defect.~~ **No.** FunMaxMusic builds 24, 25, 26, 27 and 28 all
    share pre-release version `1.0` and each carries its own distinct note. Per-build notes on one
    version demonstrably work on this account.

  Also cleared: `scripts/verify-core-tests.sh` is the only thing this repo runs that the sibling does
  not, and it creates `tmp/` and runs `swift test` and deletes nothing, so it is not eating the file
  between `ci_post_clone` and the upload.

  **The log bundles have now been compared — runs 3 and 9 against runs 4, 5 and 6 — and they cannot
  answer it.** This was the last outstanding lead and it is a dead end, so it is recorded rather than
  left looking promising:

  - All five bundles hold the same 25 files. `xcodebuild-archive.log` is 1133 lines in every one of
    them, `ci_pre_xcodebuild.log` 97, and the three export logs agree within a single line.
  - `ci_post_clone.log` is identical in shape across all five and correct in all five, writing
    `/Volumes/workspace/repository/NoSpoilers/TestFlight/WhatToTest.en-GB.txt` with that run's own
    subject and hash. The hook was already cleared on the failing runs; it is now cleared on the
    working ones too, which is the half that was missing.
  - **`WhatToTest` appears in no other file in any bundle.** Not in the archive log, not in the
    export logs, not in the distribution logs.
  - A normalised diff of run 5's app-store export against run 9's — timestamps, UUIDs and numbers
    stripped — differs only in `__NSSingleObjectArrayI` pointer addresses and one first-run
    `Capabilities` directory creation. That is memory-address noise.
  - `DVTITunesSoftwareService.log` is **one line**. The upload to App Store Connect is not in this
    bundle, and no artifact type carries it: the action offers `ARCHIVE`, three `ARCHIVE_EXPORT`s,
    `RESULT_BUNDLE` and `LOG_BUNDLE`, and none is an upload log.

  So the note is attached server-side, after the last step Xcode Cloud shows you, and **no artifact
  Apple exposes records whether it was read.** The runs are indistinguishable from this side, which
  means the difference is not in anything this repo controls or can see. Chasing it further needs a
  channel other than the log bundles.

  **Resolved by not depending on it.** `testflight_distribute.py` now writes the note itself: it asks
  the run for the commit — a build's version *is* its run number, per Decision 1 — and `PATCH`es
  `betaBuildLocalizations`. Apple's pickup is off the critical path, and the failure mode is an HTTP
  error rather than silence. Proven on build 6, which read `Build 3 from e762f5c7d8d7` and now reads
  `Build 6 from 5dc0d8f16db0`.

  **Only the `PATCH` half has ever run, and the reading that said otherwise was wrong.** Build 6
  exercised it with a localization whose text was another build's; build 12 exercised it again with
  one whose text was `null`. `write_note`'s `POST` branch — the one that creates a localization —
  **has never executed**, and on the evidence above it may never execute, because Apple always
  leaves one there to patch.

  This was recorded here as "build 12 exercised the `POST`" and that was a mistake worth keeping,
  because of *how* it was made. `repair_note` prints `what to test: is missing` from
  `current = existing["whatsNew"] if existing else None`, so **one message covers two different
  states**: no localization, and a localization holding nothing. Build 12 printed `is missing` and
  the branch was inferred from the message. Builds 11 and 13 are what settle it — both untouched by
  the script, both carrying an empty localization — so build 12 arrived holding one too and the
  `existing is None` test was false.

  **The message now says which of the two it saw.** `note_state` replaced the inline conditional and
  reports four states — `has no en-GB localization`, `is empty`, `claims '…'`, `has no build
  marker` — so the line names the branch `write_note` is about to take instead of hiding it. Build
  13 read `what to test: is empty. Would set 'Build 13 from 7fec1d7f88e7'` on the dry run and
  `is empty, now 'Build 13 from 7fec1d7f88e7'` on `--apply` — naming the `PATCH` in both, which is
  the reading that was unavailable when this was got wrong. Five selftest cases pin the four
  states, 20 → 25.

  It is worth naming the shape, because this file has now hit it twice: **a diagnostic that
  collapses two states produces a confident wrong answer, not an obviously missing one.** The other
  was `GET /v1/betaGroups/{id}/builds` returning an empty list whether or not the build is in the
  group. Both read as information. Neither is.

  The check is **"does the note name this build"**, not "is there a note" — the `Build N from <sha>`
  marker, not the subject. Two commits off the same branch routinely share a subject (builds 3 and 6
  were both `task update`), so the subject cannot tell them apart and the marker always can.

  **Builds 4 and 5 have been left carrying build 3's note on purpose**, as the surviving specimen of
  the original fault. Do not tidy them up.

  **`ci_post_clone.sh` has been deleted**, so one thing writes the note and it is the thing whose
  failures are visible. Keeping it as a fallback was considered and rejected: a fallback that
  disagrees with the primary and reports nothing is precisely how build 4, 5 and 6's notes went wrong
  in the first place, and it would have put the unreliable mechanism back on the path for exactly the
  builds nobody checks.

  The cost, stated plainly: **a build nobody distributes now has no note of its own**, and App Store
  Connect may show it a previous build's. That is the right way round — an undistributed build
  reaches no tester, and the note becomes correct at the moment it starts mattering — but it does
  mean the TestFlight UI can show a note for a build no human has been given.

  Until then: **do not read a plausible-looking note as proof it came from this build** — check the
  build number inside it. A stale note is worse than no note, because it describes changes the
  tester does not have.
- **The gate is a script, not a feature.** It works — run 8 proves it — but anyone who deletes the
  `verify-core-tests.sh` line from `ci_pre_xcodebuild.sh` removes it silently, and the run stays
  green. Nothing in Xcode Cloud will report that. Proving it once does not make it durable, and
  re-proving it costs a red push and a revert.
- **A failed run hides the next failure behind it.** Run 8 failed at the gate, which is what it was
  built to do, and in doing so concealed that its build number was already taken on `1.0.22`. A hook
  that exits early means every later step is untested for that commit, so "the run failed for the
  reason I expected" is never the same as "there was one thing wrong".
- **TestFlight builds expire 90 days after upload** and then stop launching, with nothing to explain
  it beyond "Expired Build".
- **Every internal tester is an account on the developer team.** There is no read-only "just let them
  test" role; Marketing is as small as it gets. Beyond a handful of trusted people this is the wrong
  mechanism, and Phase 7 is the right one.
- **The distribution audience is decided once per build, at archive time.** Nothing warns you that a
  run's output is ineligible for the audience you will want next month.
- **Delivery is a step somebody has to remember.** That is the deliberate choice in Phase 1 step 6,
  and this is its cost: forget the command and every signal — green run, `VALID` build,
  `READY_FOR_BETA_TESTING`, `hasAccessToAllBuilds: true`, working public link — reads as success
  while the testers sit on a build from a fortnight ago. The mitigation now exists — the
  `testers can install` line in `appstore_status.py` — but it is still only something that tells
  you when the habit lapsed, not a mechanism. **It is deliberately silent about being behind**, so
  it will report `5 builds behind` in the same untroubled tone whether that is an afternoon's
  pushes or a month of forgetting. Nothing can distinguish those for you.
- **A group with no builds gives no error, it gives silence.** The tester stays `NOT_INVITED`
  forever and no email is ever sent. Check with `GET /v1/builds/{id}?include=betaGroups` after
  every archive; an empty `included` is the whole diagnosis.
- **Two release paths to one App Store record.** Xcode Cloud and `release.sh` both upload under the
  same bundle identifier. The offset keeps their numbers apart; nothing enforces it but this task
  file.

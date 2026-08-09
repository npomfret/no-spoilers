# Task 14: Xcode Cloud → TestFlight for the iOS app

**Status:** IN PROGRESS — scripts written and locally verified; Phase 1 (the Xcode Cloud workflow) and the
tester group still need doing in Xcode and App Store Connect, and nothing has been pushed yet.
**Depends on:** nothing — the App Store Connect record, API key, and signing already work via `scripts/ship-ios.sh`
**Effort:** ~2 hours, most of it spent on the two decisions in Phase 0

## Decisions taken

- **Decision 1: offset the run number.** `BUILD_OFFSET=1000` in `ci_pre_xcodebuild.sh`. Option 1 as recommended.
- **Decision 2: gate in `ci_pre_xcodebuild.sh`.** It calls `scripts/verify-core-tests.sh`. No Xcode test target
  was added. Option 1 as recommended.
- **Decision 3: delivery to testers is a command, not a post-action.** Reversed on 2026-08-09 after the
  sibling project ran it both ways — the reasoning is in Phase 1 step 6, and it changes what the status
  report is allowed to warn about (Phase 7).
- **Shebang:** both hooks are `#!/usr/bin/env bash` with `set -euo pipefail` (pre-build only), matching every
  other script in `scripts/`, rather than the `#!/bin/sh` in the Phase 3/4 drafts below. `ci_post_clone.sh`
  deliberately omits `set -e` — see Phase 4.

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

   **The group has no testers in it.** An empty group builds and delivers fine and reaches nobody.

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

---

## Phase 2: Where the CI scripts go — DONE

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

Add `NoSpoilers/TestFlight/` to `.gitignore`; it is generated per build. Done, as `/NoSpoilers/TestFlight/`.

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

## Phase 4: `ci_scripts/ci_post_clone.sh` — DONE

Written to `NoSpoilers/ci_scripts/ci_post_clone.sh`, mode `755`, and authoritative in the same way. It writes
the TestFlight *What to Test* note from the commit being built, so nobody has to remember to.

One change from the draft: it checks `CI_PRIMARY_REPOSITORY_PATH` explicitly rather than leaning on `mkdir -p`
failing. Unset, the draft would have tried to create `/NoSpoilers/TestFlight` at the filesystem root and
reported nothing about why the note was missing.

**Opposite rule to the other script: a non-zero `ci_post_clone.sh` fails the entire run.** Every path
ends at `exit 0` — no missing tester note is worth a failed delivery. Do not put the test gate here. This is
also why this one script does not carry the repo-standard `set -euo pipefail`.

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
| App Store Connect API key | `AuthKey_S394C74APG.p8`, issuer `69a6de6e-…` | Already used by `ship-ios.sh` and proven — but it is a **Developer**-level key. Enough for everything in Phases 1–6; not enough for Phase 7. See below |
| Signing | automatic, team `6FZN56WC8G` | Xcode Cloud manages its own certificates; `ExportOptions-AppStore.plist` is not used by it |
| App Store Connect record | app `6761343835`, highest existing build **8** | Confirms the `+ 1000` offset lands clear of everything already uploaded |
| Xcode Cloud product | **does not exist yet** | `GET /v1/ciProducts` returns only `FunMaxMusic`. The API cannot create one — Phase 1 has to happen in Xcode |

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

So this is a command, and it is the whole delivery step. The sibling project has it at
`scripts/testflight_distribute.py`, worth copying rather than rewriting: dry-run by default,
`--apply` to add the newest build, `--apply --submit` to send it for review as well. **It touches
internal groups only unless `--group` names one** — reaching a public link should cost you the
effort of typing its name, so that no future change to a default can publish something on your
behalf.

Keep it separate from whatever reads state. One script writes to App Store Connect, one only
issues `GET`s, and that split is what makes the report safe to run whenever the answer is in
doubt. It is also a real boundary: the read-only script runs on a Developer key, and only the
distributing one is given the App Manager key.

### What the status report should say, once delivery is manual

This is the trap in the change. With no post-action, **the newest build is in no group as a matter
of course**, so a "newest `VALID` build reaches nobody" warning fires after every single push. A
warning that is always on is the same as no warning, and it takes the exit code with it.

Report the useful fact instead — **which build the testers can actually install, and how far
behind the newest it has fallen** — and warn only when they can install *nothing at all*, which is
the genuine failure:

```
  tester groups: Internal
  testers can install: v1024, 1 build behind v1025
```

There is no cheap query for it. Walk the live builds newest-first, asking each one `GET
/v1/builds/{id}?include=betaGroups` until one comes back with a non-empty `included`, and stop
after ten. That is one request per undistributed build, which is the price of the group's own
build list being useless.

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

- [x] `ci_post_clone.sh` writes `WhatToTest.en-GB.txt` containing the commit subject, build number and
      12-character hash. Exit 0.
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

### Still needs a real run

- [ ] A push to `main` produces a run that reaches `SUCCEEDED`.
- [ ] The build appears in TestFlight as `VALID`, not *Missing Compliance*.
- [ ] **The build reaches no group on its own**, which is the intended behaviour and worth seeing
      once: `GET /v1/builds/{id}?include=betaGroups` comes back with an empty `included` after a
      green run.
- [ ] **A tester can actually install it after the distribute command.** The same query then names
      `Internal`, and the tester's `state` is `INVITED` rather than `NOT_INVITED`. `VALID` proves
      neither. Note that adding the build sends any pending invitation by itself, and that `state`
      reads are eventually consistent — it can read `NOT_INVITED` again minutes later and settle.
- [ ] **A tester who has not redeemed the invite still sees "no builds available."** Check
      `appDevices` on the tester: an empty array means the code was never redeemed on a device, and
      no amount of distributing will change what they see. Diagnose that before touching the build.
- [ ] Its build number is `CI_BUILD_NUMBER + 1000` and is higher than anything `release.sh` shipped.
- [ ] The widget extension's build number matches the app's.
- [ ] *What to Test* in TestFlight shows the commit subject and short hash.
- [ ] Breaking a `NoSpoilersCore` test and pushing produces a **failed run and no new TestFlight
      build**. This is the one that proves the gate, and it is the only way to know Decision 2 worked.
- [ ] `scripts/ship-ios.sh` still works afterwards and does not collide with a CI build number.

---

## Open risks

- ~~**`verify-core-tests.sh` on a clean runner.**~~ Closed: verified against a fresh clone, needs nothing
  outside the checkout. Still worth watching on the first real run, since an Xcode Cloud runner is not
  this machine.
- **The hook runs before every `xcodebuild` invocation in the action**, so the core tests may run more
  than once per build. Left as-is: a skip marker would be another way for the gate to silently disappear.
  If it shows up in the compute numbers, revisit it here rather than in the script.
- **Compute allowance.** Archiving on every push spends against 25 hours a month that do not roll
  over. If `main` is busy, move the start condition to a tag or manual trigger. Adding the core tests
  to every build makes each run longer.
- **The gate is a script, not a feature.** Anyone who deletes the `verify-core-tests.sh` line from
  `ci_pre_xcodebuild.sh` removes the gate silently, and the run stays green. Nothing in Xcode Cloud
  will report that.
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
  while the testers sit on a build from a fortnight ago. The mitigation is the report line naming
  how far behind they are; there is no mechanism, only a habit and something that tells you when
  the habit lapsed.
- **A group with no builds gives no error, it gives silence.** The tester stays `NOT_INVITED`
  forever and no email is ever sent. Check with `GET /v1/builds/{id}?include=betaGroups` after
  every archive; an empty `included` is the whole diagnosis.
- **Two release paths to one App Store record.** Xcode Cloud and `release.sh` both upload under the
  same bundle identifier. The offset keeps their numbers apart; nothing enforces it but this task
  file.

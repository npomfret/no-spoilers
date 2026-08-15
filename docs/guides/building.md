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

- **The App Store is the core product on both platforms; Homebrew is an add-on.** Decided 2026-08-13, and `release.sh` now says so: `--platform` and `--channel` are both **required** (there is no default, because the only default was `macos` + `developer-id`, so asking for nothing shipped the add-on), and in `--channel both` the App Store upload runs **before** the Developer ID / Homebrew channel. Do not swap that back — both export from the same already-valid archive, and with Homebrew first a notary timeout killed the run before the store upload was attempted. A Homebrew failure still fails the run; it can no longer cost you the upload.
- `scripts/release.sh` is the single release engine. `scripts/ship-*.sh` are thin argument wrappers over it. **Releases run on your machine, never in CI**, and `scripts/ship.sh` is the whole of it: Mac App Store, macOS Developer ID and iOS App Store in one run, version-locked, every platform shipped whether or not its source changed.
  - **The version bump is committed and pushed only after the archive exists.** It is still edited into the working tree first, because the archive is what makes the build number real; a failed build used to leave a pushed `bump to vX (build N)` commit for an artifact nobody ever produced, and `ship.sh` runs the engine twice, so one failure could leave two. On failure the tree is left dirty and unpushed on purpose — nothing here reverts a file you may also have been editing. The commit cannot move any further down the run: the tag is pushed by whichever channel runs, and it has to point at it.
  - **One ship run is one build number.** `ship.sh` chooses it once via `current_build_number` in `_version.sh` and passes `--build` to both invocations. Left alone each invocation bumps the project again, which is why 1.1.1 is build 10001 on macOS and 10002 on iOS — one version, two builds, and "version-locked" quietly untrue. `release.sh` on its own still bumps; `--build` only pins it.
  - **The Homebrew tap is checked in preflight, before anything is built.** It is a sibling checkout (`../homebrew-tap`) that nothing here clones. Discovering it missing where it is used means discovering it after notarization has completed and the GitHub release is public, with no way to finish — so `--channel developer-id|both` fails at the top of the run if the cask file or its git checkout is absent.
  - **`gh release create` is guarded**, because it refuses an existing release and a re-run after a partial failure has already redone the expensive half. An existing `vX.Y.Z` gets `gh release upload --clobber` instead.
  - **There was a `.github/workflows/release.yml` claiming to do the Developer ID channel on a `v*` tag. It was deleted on 2026-08-12 because it had never worked — ten tag pushes since March, ten failures, each dying in about twelve seconds importing a certificate from `secrets.DEVELOPER_ID_CERT_P12`, which was never set. The repository has no secrets at all.** It was a duplicate of what `ship.sh` already does locally, so nothing was lost, and every release you have ever shipped went out from a laptop. What it cost was worse than nothing: a red cross on every release tag, teaching everyone that a failed run on a release is normal.
- Xcode Cloud archives **both** schemes on every push to `main` and uploads both: `NoSpoilersApp` for iOS and `NoSpoilers` for macOS, two ARCHIVE actions in one workflow. **The build arrives attached to no tester group and nobody can install it until it is put in one** — that is a command somebody runs, deliberately, not a post-action. The argument for that, and the rest of what handing a build over involves, is under **TestFlight** below. Its hook lives in `NoSpoilers/ci_scripts/`, beside the Xcode project — Xcode Cloud ignores a `ci_scripts` directory at the repository root.
  - **The macOS action was added 2026-08-14.** Before it, macOS had no CI, no test gate and no beta channel, so Homebrew was the only fast way to get a Mac build to anyone — which is why it read as the core product however often the docs called it an add-on. One workflow rather than two, deliberately: actions in a workflow share the run number, so one commit produces iOS build N and macOS build N. Two workflows would have made the platforms drift apart by build number for no gain, which is the same defect `ship.sh` was just fixed for.
  - Actions run concurrently and the distribution audience belongs to each archive action alone, so a macOS signing failure does not stop the iOS build being delivered. That is the same property that makes the pre-build hook the only real gate.
  - **`ci_pre_xcodebuild.sh` now runs once per action**, so `verify-core-tests.sh` runs twice per push. It is the gate for both platforms and it is unchanged — it stamps the project, which both schemes read.
  - **Proven by run 15 on 2026-08-14**, the first run to archive macOS: both actions SUCCEEDED, and both platforms landed `1.1.1 build 15` VALID on App Store Connect. Xcode Cloud provisioned macOS App Store signing itself, on a project that had only ever signed macOS locally. Same run number on both platforms is the point of the single workflow.
  - **A macOS CI build uploads, processes, goes `VALID`, and reaches nobody until somebody hands it over** — confirmed on build 15, whose `include=betaGroups` was empty while every other signal read as success. `scripts/testflight_distribute.py --platform macos --apply` is that step; without `--platform` it still means iOS, so the Mac build is a second, separate decision rather than a side effect of the iOS one. Delivered this way on 2026-08-14: macOS 1.1.1 build 15 → Internal, `IN_BETA_TESTING`.
  - **The report still cannot see it.** `appstore_status.py` covers one platform (`TESTFLIGHT_PLATFORM = "IOS"`), so a stranded Mac build and no Mac build print identically. Showing both means threading the platform through `distribution`, `attention`, `render` and the fixtures — and hoisting the tester-group fetch out of `distribution` first, since the groups are app-wide and a naive loop would fetch and print them twice. See `tasks/23-status-report-is-ios-only.md`.
  - `ci_pre_xcodebuild.sh` runs `scripts/verify-core-tests.sh` and then stamps `CURRENT_PROJECT_VERSION` to `CI_BUILD_NUMBER`. It is the only hook.
  - **There is deliberately no `ci_post_clone.sh`.** One existed, writing `NoSpoilers/TestFlight/WhatToTest.en-GB.txt` from the commit subject, and App Store Connect read that file on some runs and not others — builds 3 and 9 carried their own note, builds 4, 5 and 6 all carried build 3's. Nothing in any artifact records whether the file was read, so a working run and a broken one are indistinguishable. Do not reinstate it; `testflight_distribute.py` writes the note over the API instead, and two mechanisms writing one note is how you get a stale one nobody can explain.
- **Deleting and recreating an Xcode Cloud product costs a marketing version.** A new product restarts `CI_BUILD_NUMBER` at 1, but the builds the old product uploaded are still on the app record, so the first archive re-presents a `(version, build)` pair that is already spent. **It does not fail the build** — it compiles, tests, archives, goes green, and dies minutes later at *"Preparing build for App Store Connect failed"*. A green run is not a delivered build. Bump `MARKETING_VERSION` before the first push after a recreation; that is the only mitigation that does not require knowing which numbers are free. Both projects did this on 2026-08-12 (`no-spoilers` 1.0.22 → 1.1.0) and both landed on run 1. To see what is spent:
  ```
  GET /v1/builds?filter[app]={id}&filter[preReleaseVersion.platform]=IOS
      &include=preReleaseVersion&limit=200
  ```
  `included` carries the marketing versions; each build joins via `relationships.preReleaseVersion.data.id`. (`/v1/apps/{id}/builds` returns HTTP 400 for that include; the filtered collection accepts it.) **Trains have holes** — 1.0.22 is missing builds 1, 2 and 7 — so "next number" and "next free number" are different questions, and a collision can land several green runs in rather than immediately. Two things make the holes misleading: **an expired build still occupies its number** (it stops launching, it does not free anything), and **`autoCancel` burns numbers too** — push two commits and the first starts a run the second cancels, and a `CANCELED` run consumes its number exactly as a delivered one does. A run number is not a promise that a build exists.
- **`GET /v1/ciProducts` is a cache and it lies in both directions.** It lists products that answer `404` by id, and has omitted live ones. Only the by-id call is honest; `scripts/ci_health.py` re-fetches every listed id, which is why it reports ghosts separately. Run it immediately after Integrate → Create Workflow. **That wizard has only ever created successfully from a team with zero products** — run with one already present it seized the existing one three times between 2026-08-08 and 2026-08-12, renaming it and repointing it at whichever repo ran the wizard, invisibly from the victim's side. **If it errors, stop and do not retry**: the damage happens before the error is shown, so a retry takes the next product. Two projects share Apple team `6FZN56WC8G`, so the blast radius includes `super-funmax-music`.
- **Restore baseline for this repo's product**, so it can be rebuilt if it is ever lost. Verified by `ci_health.py` on 2026-08-13:
  ```
  product           9C40B27D-5C9B-4AB2-A9A2-6B97616BAA3F  "NoSpoilersApp"
  app               6761343835  pomocorp.NoSpoilers.NoSpoilersMac
  repository        npomfret/no-spoilers
  workflow          7A43B70B-3311-4954-A625-AB82333B6503  "NoSpoilers", enabled, not locked
  containerFilePath NoSpoilers/NoSpoilers.xcodeproj
  branch            main (exact, not prefix), autoCancel true, no file/folder rule
  pull requests     no start condition; no tag or schedule condition
  action 1  ARCHIVE  "Archive - iOS", scheme NoSpoilersApp, IOS, APP_STORE_ELIGIBLE,
                     isRequiredToPass true, destination null
  action 2  ARCHIVE  "Archive - macOS", scheme NoSpoilers, MACOS, APP_STORE_ELIGIBLE,
                     isRequiredToPass true, destination ANY_MAC   (added 2026-08-14)
  ```
  Name the workflow `NoSpoilers`, never `Default` — two products both called `Default` under one team is how the wizard's victim goes unnoticed. It was `NoSpoilers iOS` until 2026-08-14; the platform came out of the name when the macOS action went in, because a workflow that says iOS and archives both is the kind of drift that makes people trust the wrong thing. No TEST action by design; the gate is `ci_pre_xcodebuild.sh`, above.
  - Adding the action was `PATCH /v1/ciWorkflows/{id}` with `attributes.actions` set to the whole array, existing action included — the field replaces, it does not append, so a PATCH that omits action 1 deletes it. The `CiPlatform` value is `MACOS`, **not** the `MAC_OS` that `filter[preReleaseVersion.platform]` wants on `/v1/builds`; the two enums differ by an underscore and only one of them is ever right in a given call. Send `destination: null` and the server fills in `ANY_MAC` itself. `ciProducts` has no PATCH, but `ciWorkflows` does, so this is an edit and not a re-run of the wizard that keeps hijacking the sibling project.
- **The two upload paths are kept apart by the committed `CURRENT_PROJECT_VERSION`, which starts at `10000`.** `release.sh` increments from there (10001, 10002, …), one step per ship run now rather than one per platform; Xcode Cloud uses its run number. Do not lower that committed value — build numbers only ever increase, and the bands would start to overlap. **The two bands have never actually been exercised against each other** — `release.sh` has not run since the `10000` bump — so this is a design that holds on paper and nowhere else yet. See `tasks/22-release-path-unrehearsed.md`.
- No CI script can influence the build number that reaches App Store Connect: Xcode Cloud rewrites `CFBundleVersion` to `CI_BUILD_NUMBER` when it exports the IPA, after the hook and after the archive. The stamp exists so the archive agrees with the upload, not to control it. Measured on run 3, which stamped `1003`: the xcarchive read `1003` and the uploaded IPA read `3`. An earlier `BUILD_OFFSET=1000` in the hook was built on the assumption that it could, and run 3 is what disproved it.
- Xcode Cloud does not gate delivery on its TEST action, so the `verify-core-tests.sh` call in `ci_pre_xcodebuild.sh` is the only test gate on TestFlight builds. Removing it leaves runs green and the gate gone.
- **An Xcode Cloud build reaches no tester group on its own.** `scripts/testflight_distribute.py` is the step that hands it over — dry-run by default, `--apply` to act, `--apply --submit` to send an external build for Beta App Review. Nothing runs it for you; that is Phase 1 step 6's deliberate choice, and forgetting it looks exactly like success.
  - **Newest means most recently uploaded, not the highest build number.** The two upload bands above make numeric order meaningless: a fresh CI build is `5` while last month's manual upload is `10001`.
  - It touches internal groups only unless `--group` names one, so no default can ever feed the public link.
  - **It also repairs the *What to Test* note**, since the hook's file is only sometimes picked up. It asks the Xcode Cloud run for the commit — a build's version is its run number — and writes `whatsNew` over the API. The test is not "is there a note" but "does the note name *this* build": the failure mode is a well-formed note about somebody else's commit, which reads as correct and describes changes the tester does not have.
- `scripts/appstore_status.py` reads what App Store Connect holds for both platforms and writes nothing. Keep it that way: `release.sh` and `testflight_distribute.py` are the only things here that write, and the split is what makes the report safe to run at any time. It is stdlib-only Python and needs no venv or install, and it owns the shared token signing, app lookup and build selection that the distribute script imports.
  - **Its `TESTFLIGHT` section answers "what can a tester install right now", not "does a build exist".** It walks the unexpired iOS builds newest-first asking each `?include=betaGroups` until one is in a group, and prints how far behind that has fallen — `testers can install build 4, 5 builds behind build 11`. **Being behind is never a warning.** Delivery is a manual command, so the newest build reaches nobody after every push; warning about it would leave the report permanently red and take the exit code with it. Only installing *nothing* is reported under NEEDS YOU.
- **The two Python scripts hold different App Store Connect keys, and that is the point.** The report runs on the Developer-level key `S394C74APG`; only `testflight_distribute.py` uses the App Manager key `ASC6H3SL2D`. A Developer key reads every endpoint involved and is then refused the write with an empty `403` that looks like a malformed request.

## TestFlight

Everything below was established while building the Xcode Cloud → TestFlight path, and the chain has
been proven end to end on the real thing: push, archive, gate, upload, `testflight_distribute.py
--apply`, a person tapping Install on build 13 (commit `7fec1d7`, 2026-08-10).

- **A build reaches no group of any kind until it is put there**, internal groups included. This is
  the fact that took longest to accept, because nothing contradicts it out loud: the run is green,
  the build is `VALID`, `internalBuildState` reads `READY_FOR_BETA_TESTING`, and every tester has
  nothing. `hasAccessToAllBuilds` governs which builds a tester *may* see, not which ones exist for
  them. `POST /v1/betaGroups/{group}/relationships/builds` → 204 is the whole procedure for an
  internal group, and a pending invitation sends itself immediately afterwards.
- **A group with no builds gives silence, not an error.** The tester stays `NOT_INVITED` for ever
  and no email is ever sent. Check with `GET /v1/builds/{id}?include=betaGroups` after every
  archive; an empty `included` is the entire diagnosis.
- **Read a tester's `state`; treat `appDevices` as telling you nothing.** A tester on a phone that
  had just installed build 13 read `state INSTALLED` with `appDevices []`, stable across three
  reads. `state` moved `NOT_INVITED` → `INVITED` → `INSTALLED` across the three things that actually
  happened; `appDevices` never moved at all. Using it as the redemption test declares a working
  setup broken.
- **Ask the group, not the tester.** `GET /v1/betaGroups/{id}/betaTesters` populates `state` and
  `appDevices`. `GET /v1/betaTesters/{id}` returns `None` for both on the same tester in the same
  second, and `GET /v1/betaTesters/{id}/appDevices` is a flat `404` — that relationship does not
  exist. `None` reads exactly like "no devices", so the instinctive query gives the right diagnosis
  by accident and the wrong one just as easily.
- **`GET /v1/builds/{id}/buildBetaDetail` is where a build says what it needs.**
  `externalBuildState` is the field that answers honestly: `READY_FOR_BETA_SUBMISSION` needs review,
  `READY_FOR_BETA_TESTING` is approved and can simply be handed over, and **`NOT_APPLICABLE` marks a
  build archived `INTERNAL_ONLY`** — the one state no retry, setting or resubmission will move. Only
  builds archived after the action became `APP_STORE_ELIGIBLE` qualify; getting that wrong is not a
  setting to change, it is a new build.
- **A TestFlight build stops launching 90 days after upload**, with nothing to explain it beyond
  "Expired Build". `appstore_status.py` drops expired builds rather than ranking them last — an
  expired build is not a worse answer to "what can they install", it is not an answer.
- **Every internal tester is an account on the developer team.** There is no read-only "just let
  them test" role; Marketing is as small as it gets. Beyond a handful of trusted people, external
  testing is the right mechanism.

### External testers

Only needed for someone you will not add to the team. Internal testing is simpler and has no
review — do not take this on unless you need it. It buys up to 10,000 testers invited by email or a
public link they tap, with no account to administer. It costs a **Beta App Review for the first
build of each marketing version** — days rather than hours — so bumping `MARKETING_VERSION` puts you
back in the queue; only 6 builds per 24 hours may be submitted and only one build per version may be
in review at a time. `testflight_distribute.py --apply --submit` posts
`/v1/betaAppReviewSubmissions` for you, and touches internal groups only unless `--group` names one,
so no default can ever feed the public link.

Prerequisites, in the order they bite: the archive action must be `APP_STORE_ELIGIBLE`; an internal
group must exist first, because Apple requires one before an external group can be created; the app
record needs Test Information — a beta app description and a feedback email — or external testing is
blocked; and export compliance must already be answered (`ITSAppUsesNonExemptEncryption` is set on
the target).

**Create the external group and the Test Information in the App Store Connect UI, not the API**, and
the reason generalises past TestFlight:

| Request | Result |
|---|---|
| `POST /v1/betaGroups` with `isInternalGroup: true` | **201** |
| `POST /v1/betaGroups` with `isInternalGroup: false` | **403**, `detail` empty |
| `POST /v1/betaAppLocalizations` | **403**, "The API key in use does not allow this request" |

A Developer-level key manages Xcode Cloud and internal TestFlight but not app metadata and not
external distribution, and the second message names the cause the first one hides. **Read a bare 403
with an empty `detail` from this API as "your key is not allowed to do this", never as "your request
was malformed"** — the two are indistinguishable from the response alone, and the empty one will
send you rewriting a body that was fine.

**A public link is created per external group and should be capped at a tester count.** Unlimited is
the setting you cannot walk back once the URL is out of your hands: a public link cannot be
un-shared, only disabled after the fact. The link distributes nothing until a build passes review,
so it is safe to create early.

## App Store screenshots

`scripts/screenshots.py` captures them from a simulator against fixture data. Its docstring is the
long-form reference and is kept current; what follows is the policy around it.

```
scripts/screenshots.py --device "iPhone 11 Pro Max" --expect 1242x2688 --widget-size large
```

`--device` takes a simulator name or a UDID and is repeatable. **A name matching more than one
simulator is refused**, not guessed at — the script prints the candidate UDIDs and stops, which is
the common case on a machine carrying several runtimes. `--dry-run` prints the plan and touches
nothing.

- **Screenshots are taken against a fixture, never the live calendar**, so the same command produces
  the same picture in March and in August. Out of season the widget correctly renders its off-season
  state, and mid-season it renders whichever race happens to be next; neither is a listing asset.
  The fixture offsets are relative to run time and must stay that way.
- **Never launch the app to make it pick up the fixture.** `ScheduleStore.refresh()` saves the
  network result unconditionally, so launching replaces the fixture with the real calendar. The
  script seeds, reboots and captures without ever opening the app, and that sequence is not
  incidental.
- **Placing the widget is `--widget-size`, not a manual step.** There is no `simctl` verb for it, but
  SpringBoard keeps the Home Screen layout in `Library/SpringBoard/IconState.plist` and reads it back
  on boot, so the widget and its family are just data. It has to be written while the device is shut
  down or SpringBoard undoes it on exit. Ask for a family the widget does not declare and the entry
  is silently dropped, so `WIDGET_SIZES` and the widget's declared families must stay in step.
- **`--install` is the only thing that invalidates a stored timeline.** WidgetKit keeps it in
  `chronod/chrono.sql` until its own reload date — hours away for this widget. Rebooting, restarting
  `chronod`, and deleting `chrono.sql` were all tried and none of them work. The first capture after
  an install is blank because the extension is not registered yet, so the sequence for a device that
  has been captured before is `--install` once, then capture again.
- **Pick the device by the pixel size the listing slot accepts, not by what is newest**, and pass
  `--expect` so a wrong one fails in seconds rather than at upload. `iPhone 11 Pro Max` is natively
  1242 × 2688 and accepted; `iPhone 17 Pro Max` at 1320 × 2868 is refused.
- **A blank or stale widget still exits 0 with a valid PNG.** `--expect` checks pixel dimensions and
  `confirm_widget_size()` checks the layout entry survived; neither can tell you the widget rendered
  real content. Both failures were seen on 2026-08-13 and both look like a successful run. **Look at
  the picture before uploading it** — that is the check, and there is not a scripted substitute.
- **Do not widen `SETTLE_SECONDS` to make a grey capture come good.** The widget's first timeline is
  genuinely slow to build; see `tasks/19-widget-timeline-too-large.md`. Widening the delay hides that
  on the one machine that takes screenshots and leaves it in front of every user.
- Two runs with no code change are **not** byte-identical and cannot be — the countdowns advance and
  the status-bar clock moves. Expect them to differ only in those.
- **Keep `INFOPLIST_KEY_CFBundleDisplayName` set on the iOS target.** Without it the Home Screen name
  falls back through `PRODUCT_NAME` to `TARGET_NAME` and reads `NoSpoilersApp`. Only a widget
  screenshot shows this, because only the widget puts the containing app's name on screen; it was
  found this way in `7d64a1b` and would otherwise have shipped.

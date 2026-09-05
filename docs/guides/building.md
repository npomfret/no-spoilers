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

**Xcode Cloud has no compute quota left, confirmed 2026-08-22, so everything below describing it as
the ordinary path is currently describing something that does not run.** Runs 33, 34 and 35 were
each cancelled 5–8 seconds after creation with `startedDate: None` and no `cancelReason`, and
`POST /v1/ciBuildRuns` answers `500`. Nothing announces this: a push produces a run that goes away,
and the app record simply stops gaining builds. Until it resets, **a release is a local
`scripts/ship-ios.sh` run**, which is the path the rest of this section treats as the exception.
**It reset**: on 2026-09-05 run 102 archived and uploaded both platforms from `b34615d`, so pushes
to `main` produce builds again and every one of them still needs handing over (see below).
`1.1.2 build 10003` went out that way on 2026-08-22. Two things follow, and both are handled rather
than merely known: the build lands in the 10000 band (see the train-ordering note below), and its
*What to Test* note comes from git rather than from a run.

- **The App Store is the core product on both platforms; Homebrew is an add-on.** Decided 2026-08-13, and `release.sh` now says so: `--platform` and `--channel` are both **required** (there is no default, because the only default was `macos` + `developer-id`, so asking for nothing shipped the add-on), and in `--channel both` the App Store upload runs **before** the Developer ID / Homebrew channel. Do not swap that back — both export from the same already-valid archive, and with Homebrew first a notary timeout killed the run before the store upload was attempted. A Homebrew failure still fails the run; it can no longer cost you the upload.
- `scripts/release.sh` is the single release engine. `scripts/ship-*.sh` are thin argument wrappers over it. **Since 2026-08-25 a release can also run on a TeamCity agent** — see *Publishing from TeamCity* below; it is the same engine behind a preflight, not a second one. `scripts/ship.sh` is the whole of the local path: Mac App Store, macOS Developer ID and iOS App Store in one run, version-locked, every platform shipped whether or not its source changed.
  - **`release.sh` refuses to ship four things, and all four checks run before anything is edited, built or uploaded.** Added 2026-08-22, when Xcode Cloud running out of quota made this the only path anything ships through; the fourth arrived 2026-08-26.
    - **A dirty working tree.** `xcodebuild archive` builds the tree, not the commit, and the run stages only the project file — so an uncommitted edit is in the build, in the upload and in front of users while the commit, the tag and the TestFlight note all describe something else. Since the note is now derived from that commit, a dirty ship produces a note that is confidently wrong rather than merely missing. `--allow-dirty` if you mean it; nothing here ever reverts your files.
    - **A `(version, build)` pair App Store Connect would refuse**, via `appstore_status.py --spent PLATFORM VERSION BUILD`. Two hazards, one check. A spent pair compiles, archives, exports, uploads, goes green, and dies minutes later by email at *"Preparing build for App Store Connect failed"*. An **approved version** is worse in a different way: once a version is on the store its train is closed, and `altool` refuses the package at validation with `90186 Invalid Pre-Release Train` — after the archive. Publish iOS builds 18, 19 and 20 did exactly that on 2026-09-05, each pressed with `publish.args` empty the day after 1.1.2 was approved, and left `main` three bump commits (10019–10021) for builds Apple never received. Since task 30 the check reads the version's `appStoreState` first and refuses before anything is built; the answer is to ship the next version, and since task 31 `ci-publish-ios.sh` chooses that version itself when it was given none (see *Publishing from TeamCity*). The exit codes are read rather than the output — 0 free, 3 taken, anything else means the check did not run — because collapsing them would let an offline laptop read as "the number is free", which is the exact outcome it exists to prevent. (3 rather than 2: argparse owns 2 for its own usage errors.)
    - **Red tests.** `verify-core-tests.sh` runs as the release gate. **This is the same gate `ci_pre_xcodebuild.sh` applies**, and until this landed it existed only there — so when Xcode Cloud stopped running, the gate its own comment calls "the only thing standing between a broken commit and TestFlight" left the path entirely. `1.1.2 build 10003` went out ungated on 2026-08-22. There is deliberately no flag to skip it; the CI path has none either.
    - **A checkout behind its upstream.** `main` is pushed with a bare `git push`, so a checkout that is missing work the remote has cannot finish the run. When that push came after the archive it cost one: builds 958 and 990 archived for minutes and then died on a non-fast-forward on 2026-08-26, having built a number nothing recorded. **TeamCity pins a revision when a build is *queued*, not when it starts**, so a publish sitting behind another one in the queue is the ordinary way to arrive here. Being *ahead* is fine and deliberately allowed — shipping local commits the remote has not seen is the normal laptop flow, and the push carries them up — so the test is whether the upstream is an ancestor of `HEAD`, not whether the two are equal. There is no flag to skip it: the `build/N` tag has to land on a commit that is on `main`.
  - **The build number comes from App Store Connect, since task 32 (2026-09-05).** `next_build_number` in `_version.sh` asks `appstore_status.py --next-build` — the highest build the record holds on either platform, in any train, expired builds included, plus one — and takes the higher of that and the highest `build/` tag, for a number this repository tagged that never reached the record (a Developer ID release, or an upload that failed after the tag). Apple is the thing that enforces the counter, so Apple's record is the counter. **`release.sh` no longer edits `CURRENT_PROJECT_VERSION`**; the number is stamped on the `xcodebuild archive` command line, as it always was, and the committed value is frozen at 10022 — the last upload a bump commit recorded — and is not lowered. `set_build_number` in `_version.sh` now has one caller, `ci_pre_xcodebuild.sh`, and stays there because it is the careful implementation: `agvtool -all` and then a count of the configurations that took the value, where a `sed` succeeds having matched nothing. `set_marketing_version` beside it checks itself the same way.
  - **What a run leaves in git: an `open vX.Y.Z` commit only when the version changed, and a `build/N` tag on the commit it archived.** The bump commit is gone — twenty of them between 2026-08-22 and 2026-09-05, three (10019–10021) for builds Apple never received — and with it the `Built-From:` trailer it needed. The version commit is pushed **before** the archive: an opened version is real the moment somebody asks for it, and pushing first means `HEAD` is final before `xcodebuild` reads the tree, so the rebase-and-retry push (three attempts, since build 990 lost that race by one second on 2026-08-26; a conflict is not retried) can only reorder what is about to be built, never what was. The tag is written the moment the archive exists, before the export and the upload, for the reason the bump commit was committed there: an uploaded build must be recorded even if the upload then fails, and a tagged number that was never uploaded is harmless where the reverse is a build on Apple's servers nothing can name. **The archive is checked before it is tagged**: every `.app` and `.appex` under `Products/Applications` must read `CFBundleVersion` N, because the number now reaches the build from the command line alone, and an app whose widget extension disagrees is refused at upload. On failure the tree is left as it is — nothing here reverts a file you may also have been editing.
  - **One ship run is one build number.** `ship.sh` chooses it once via `next_build_number` and passes `--build` to both invocations. Left alone each invocation asks again, which is why 1.1.1 is build 10001 on macOS and 10002 on iOS — one version, two builds, and "version-locked" quietly untrue. The macOS run writes `build/N` and the iOS run finds it already on the commit; `release.sh` refuses a pinned number whose tag is on any other commit, in preflight.
  - **The Homebrew tap is checked in preflight, before anything is built.** It is a sibling checkout (`../homebrew-tap`) that nothing here clones. Discovering it missing where it is used means discovering it after notarization has completed and the GitHub release is public, with no way to finish — so `--channel developer-id|both` fails at the top of the run if the cask file or its git checkout is absent.
  - **An upload is not a delivery, and the run says so.** After a successful App Store Connect upload `release.sh` prints the `testflight_distribute.py --platform <p> --apply` command, because a build reaches no tester group on its own — whichever path uploaded it — and every other signal reads as success while it does not. That is how macOS build 32 spent three days `VALID` and uninstallable.
  - **`gh release create` is guarded**, because it refuses an existing release and a re-run after a partial failure has already redone the expensive half. An existing `vX.Y.Z` gets `gh release upload --clobber` instead.
  - **There was a `.github/workflows/release.yml` claiming to do the Developer ID channel on a `v*` tag. It was deleted on 2026-08-12 because it had never worked — ten tag pushes since March, ten failures, each dying in about twelve seconds importing a certificate from `secrets.DEVELOPER_ID_CERT_P12`, which was never set. The repository has no secrets at all.** It was a duplicate of what `ship.sh` already does locally, so nothing was lost, and every release you have ever shipped went out from a laptop. What it cost was worse than nothing: a red cross on every release tag, teaching everyone that a failed run on a release is normal.

### Publishing from TeamCity

**`Publish iOS` on `ci.snowmonkey.co.uk` archives, signs and uploads. It has no trigger.** A person
presses it, and its snapshot dependency on `Verdict` with `take-successful-builds-only` means it can
only run on a revision the five checks have already passed — press it on an unbuilt revision and it
queues the chain itself first. It holds `no-spoilers-xcode` as a **write** lock, where `Build` and
`Tests` hold read locks, so a release never races a compile. **The five verification configurations
still hold no credential and must not gain one**; everything below is in the publish configuration
alone.

`scripts/ci-publish-ios.sh` is the step. It asserts three things, chooses a version, and `exec`s
`ship-ios.sh`. Each assertion is a failure that is otherwise expensive, silent, or misdiagnosed, and
all three were learned by walking into them.

**Pressed with `publish.args` empty, it has to just work.** Decided 2026-09-05, after the fourth
red `Publish iOS` of the day: the project's version 1.1.2 had been approved the day before, three
runs reached `altool` before task 30 taught `release.sh` to refuse a closed train, and the fourth
was refused in two seconds — correctly, and still a red build for pressing a button. So the wrapper
asks `appstore_status.py --train ios <project version>` before handing over. Open, it ships the
project's version, which is how a train fills with TestFlight builds. Closed, it fetches tags and
ships `suggest_next_version` — the next patch number, the same answer `ship.sh` offers at its
prompt — and says so in the log. An unanswered question stops the run, on the same reasoning as the
`--spent` check. **This reverses a decision task 30 recorded**, that a release script which opens a
train nobody asked for is worse than one that stops; that stays true of `release.sh`, which still
ships exactly the version it is told, and the guess lives only in the one caller that is a button
rather than a person. A minor or major bump is still a person's decision: pass it in
`publish.args`. `--check` reports the version it would have shipped.

- **The login keychain.** The agents are LaunchAgents running as a real user and **their session's
  keychain is unlocked, so signing works there** — proven by build 705 on 2026-08-25, which is the
  fact this whole path rests on. It is not true of an SSH session on the same machine as the same
  user, where `codesign` fails with `errSecInternalComponent` while `security find-identity` lists
  the identity happily. So the assertion **signs a throwaway binary** rather than listing anything.
  `--check` runs the three and stops; run it on a new agent, after an OS update, and after anything
  touches the keychain, because the alternative way to ask is to press the button that uploads.
- **Two App Store Connect keys, and they are different roles.** `S394C74APG` uploads.
  `ASC6H3SL2D`, the App Manager key, is passed to `xcodebuild` as `-authenticationKeyPath` via
  `release.sh`'s `--signing-key/--signing-key-id/--signing-issuer`, because **automatic signing with
  no Xcode account falls back to the generic `iOS Team Provisioning Profile: *`** — which carries no
  App Group, so build 725 died naming a missing capability in three errors out of four and the
  account in one. An agent that had never signed would send you into entitlements. Only
  `ci-publish-ios.sh` passes the trio; omitted, it expands to nothing and a machine with an Xcode
  account archives exactly as before.
- **The push URL.** TeamCity checks the public remote out anonymously and read-only, while
  `release.sh` pushes `main` and the `build/N` tag, and `tag_approved.py` pushes the approval tag.
  It is rewritten to SSH using the agent account's own GitHub key — **unscoped and shared with
  everything else on that machine. A deploy key scoped to this repository is the better answer
  and is not done.**

**The archive and the export need different profiles, and only the archive can create one.** Build
738 archived successfully against development profiles, pushed its bump commit, and then failed the
export with `Cloud signing permission error` and `No profiles for 'pomocorp.NoSpoilers.NoSpoilersMac'
were found`. App Store export wants a *distribution* profile, and minting one is cloud signing,
which the App Manager key is refused. **The fix was to install the two `iOS Team Store` profiles by
hand**, copied from the laptop that has an Xcode account; automatic signing then used them instead
of trying to create one, and build 10008 went out. **That is a patch with a fuse in it** — profiles
expire in about a year and the failure will read as a permission problem rather than an expiry. The
durable fix is Admin role on the signing key so it can mint its own.

**A failed export still leaves a `build/N` tag, and that is the intent.** The record is written when
the archive exists, on the reasoning that the build number is then real, and 738 is the case that
tests it: archive succeeded, the number was recorded (as `bump to v1.1.2 (build 10007)` then; as a
tag now), and nothing was ever uploaded. Harmless — Apple only requires numbers to increase, and
`next_build_number` counts tags as well as the record — and a tagged number nobody uploaded is the
cheap side of the trade; the expensive side is a build on Apple's servers that nothing can name.

**The *What to Test* note reads the `build/N` tag since task 32.** Before that
`testflight_distribute.py` found the shipping commit by its `bump to vX.Y.Z (build N)` message, and
on build 10008 it reported *"nothing names the commit behind build 10008 — no Xcode Cloud run and no
ship commit"* with the commit sitting on `main`; never diagnosed. The tag path is different in the
one way that plausibly matters — the reader now fetches tags explicitly before asking, where a bump
commit on `main` was assumed to be in the clone already — and the bump path stays for 10001–10022.
Whether 10008's failure recurs on a tagged build is the first thing to look at after the next
`Publish iOS`.

**Proven end to end on 2026-08-25**: iOS `1.1.2 build 10008`, archive through App Store Connect, in
three minutes once an agent was free. Queueing is the real cost — three agents serve the whole
estate, and a `--check` run waits behind everything.

**`Distribute iOS` and `Distribute macOS` hand an uploaded build to the Internal testers.** Added
2026-09-05, the afternoon a macOS build sat processed on App Store Connect and in no group while
the iOS build from the same Xcode Cloud run was already on a phone: the step that was always a
command somebody runs is now also a button somebody presses. Each is one step, `python3
scripts/testflight_distribute.py --platform <p> --apply %distribute.args%`, on the same VCS root as
`Publish iOS`; `distribute.args` is empty by default and is where `--submit` or `--group <name>`
goes. Deliberately unlike `Publish iOS` in three ways: no snapshot dependency on `Verdict`, because
the build being handed over was archived by Xcode Cloud or by an earlier press and the revision
checked out only supplies the script; no lock, because nothing compiles; and one per platform
rather than one for both, because the script delivers one platform per run and a Mac build is a
separate decision from the iOS one. The script fetches tags itself, and the two App Store Connect
keys `ci-publish-ios.sh` asserts are the ones it needs — it fails loudly without the App Manager
key rather than reading as done. A run is red when a group refuses the build (the script exits 1),
and a press with nothing to deliver is green and says "already there". Neither had been pressed at
the time of writing.

- Xcode Cloud archives **both** schemes on every push to `main` and uploads both: `NoSpoilersApp` for iOS and `NoSpoilers` for macOS, two ARCHIVE actions in one workflow. **The build arrives attached to no tester group and nobody can install it until it is put in one** — that is a command somebody runs, deliberately, not a post-action. The argument for that, and the rest of what handing a build over involves, is under **TestFlight** below. Its hook lives in `NoSpoilers/ci_scripts/`, beside the Xcode project — Xcode Cloud ignores a `ci_scripts` directory at the repository root.
  - **The macOS action was added 2026-08-14.** Before it, macOS had no CI, no test gate and no beta channel, so Homebrew was the only fast way to get a Mac build to anyone — which is why it read as the core product however often the docs called it an add-on. One workflow rather than two, deliberately: actions in a workflow share the run number, so one commit produces iOS build N and macOS build N. Two workflows would have made the platforms drift apart by build number for no gain, which is the same defect `ship.sh` was just fixed for.
  - Actions run concurrently and the distribution audience belongs to each archive action alone, so a macOS signing failure does not stop the iOS build being delivered. That is the same property that makes the pre-build hook the only real gate.
  - **`ci_pre_xcodebuild.sh` now runs once per action**, so `verify-core-tests.sh` runs twice per push. It is the gate for both platforms and it is unchanged — it stamps the project, which both schemes read.
  - **Proven by run 15 on 2026-08-14**, the first run to archive macOS: both actions SUCCEEDED, and both platforms landed `1.1.1 build 15` VALID on App Store Connect. Xcode Cloud provisioned macOS App Store signing itself, on a project that had only ever signed macOS locally. Same run number on both platforms is the point of the single workflow.
  - **A macOS CI build uploads, processes, goes `VALID`, and reaches nobody until somebody hands it over** — confirmed on build 15, whose `include=betaGroups` was empty while every other signal read as success. `scripts/testflight_distribute.py --platform macos --apply` is that step; without `--platform` it still means iOS, so the Mac build is a second, separate decision rather than a side effect of the iOS one. Delivered this way on 2026-08-14: macOS 1.1.1 build 15 → Internal, `IN_BETA_TESTING`. **Measured again on 2026-08-17, build 15 is in no group** and the only macOS build any group holds is `10001` from 2026-08-12. Group membership is a state that can come undone, so the report is what to trust rather than the memory of having run the command.
  - **The report shows both platforms, since 2026-08-17.** It covered iOS alone for the three days after the macOS action landed, which meant a stranded Mac build and no Mac build printed identically while every other signal read as success. `appstore_status.py` now walks each platform in `TESTFLIGHT_PLATFORMS` separately and prints the tester groups once above them, because a group holds builds of both and printing it per platform would imply two audiences.
  - **Being behind is still not a warning, on either platform.** That rule is what keeps the report worth reading, and covering a second platform doubled the pressure on it: delivery is a manual command, so after every push both platforms have an undelivered newest build. Only being able to install nothing at all reaches NEEDS YOU — and a walk that ran out of builds is not that. It says so instead of guessing.
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
- **The two upload paths are kept apart by the `10000` band.** `release.sh` counted up from a committed `CURRENT_PROJECT_VERSION` of `10000` until 2026-09-05 (10001 … 10022, one step per ship run rather than one per platform), and since task 32 takes the next number from App Store Connect itself — the highest build the record holds on either platform, plus one — so the band continues from wherever the record is without a file remembering it. Xcode Cloud uses its run number. The committed value is frozen at `10022` and is not a build setting the archive reads; do not lower it, because a local Xcode build stamps it into a bundle and build numbers only ever increase. **The separation has been observed on the real app record**, measured 2026-08-16: the macOS 1.1.1 train holds `10001` beside Xcode Cloud's 15, 16 and 17, and the iOS 1.1.1 train holds `10002` beside its 1 through 17. Nothing collided. The current `release.sh` has since shipped the iOS channel twenty times and the macOS App Store channel once (`10006`, 2026-08-23); the Developer ID channel and a three-channel `ship.sh` run are still untried under it — see `tasks/26-first-macos-release-since-the-rewrite.md`.

- **Three tag families, since task 32 (2026-09-05), and each means one thing.** Before it there was one, `vX.Y.Z`, written at the *first* upload of a train, which is not the build users got: `v1.1.2` marks `bump to v1.1.2 (build 10003)` and the build on sale is 10012. Those 26 bare tags, up to and including `v1.1.3`, are left where they are — the Homebrew cask and the GitHub releases point at them — and mean "first upload of that train". Going forward:
  - `build/N` — this commit was archived as build N. One per upload, annotated, written by `release.sh` on the commit it archived, the moment the archive exists. This is the record of an upload and the reason there is no bump commit. A second press on an unchanged commit gets a new number and a second tag on the same commit.
  - `ios/vX.Y.Z` and `macos/vX.Y.Z` — the build of X.Y.Z Apple approved for that platform, on that build's commit. Written by `scripts/tag_approved.py PLATFORM VERSION --apply`, which asks `appstore_status.py --approved` for the build number and `ship_commit` for its commit (`build/N`, or the bump commit for 10001–10022). Two names because the platforms are approved at different builds — iOS 1.1.2 at 10012, macOS 1.1.2 not yet submitted. `ci-publish-ios.sh` runs it for iOS the moment `--train` reports a version closed, before opening the next one; a person runs it for macOS. It never moves a tag: one already on the right commit is kept, one on a different commit stops the run.
  - `vX.Y.Z` — the macOS Developer ID release, that channel only, annotated. Kept under the bare name because the cask downloads `releases/download/v#{version}/…`. The App Store channels no longer tag a version at upload.
  - `suggest_next_version` reads all three version families, so a version approved on the store under `ios/` is not offered again. **Tags have to be fetched wherever they are read** — a TeamCity checkout carries none — and `next_build_number`, `release.sh`'s preflight, `testflight_distribute.py` and `tag_approved.py` each fetch before asking.

- **The cost of the bands is that the newest build looks missing in TestFlight.** TestFlight orders builds by number within a version train, so a `10000`-band build outranks every Xcode Cloud build in that train permanently. Observed 2026-08-17: iOS 1.1.1 read `[10002, 18, 17, … 1]` with `10002` uploaded 12 August and `18` uploaded 16 August — the newest build four days newer and nineteenth in the list. macOS 1.1.1 was the same shape. Nothing is broken and testers can install the newest build; it just is not where anyone looks for it.

- **Raising `CURRENT_PROJECT_VERSION` cannot fix that ordering, and neither can the CI hook.** Xcode Cloud rewrites `CFBundleVersion` to `CI_BUILD_NUMBER` when it exports the IPA — after `ci_pre_xcodebuild.sh` and after the archive — so CI builds are 19, 20, 21 whatever the project says. Run 3 proved it: the xcarchive read `1003` and the uploaded IPA read `3`. See the comment at the top of `NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh`.

- **What does fix it is opening a new train**: bump `MARKETING_VERSION`. A fresh train contains no `10000`-band build, so the next Xcode Cloud run is top of its own group. Done on 2026-08-17, 1.1.1 → 1.1.2, with `CURRENT_PROJECT_VERSION` left at `10002`. The catch: shipping that train with `release.sh` puts `10003` into it and the problem returns — which is what happened on 2026-08-22, Xcode Cloud having no quota left to put anything above it. Tidying an existing train means expiring the `10000`-band builds in App Store Connect, which is a browser action — `scripts/appstore_status.py` is GET-only by design.
- No CI script can influence the build number that reaches App Store Connect: Xcode Cloud rewrites `CFBundleVersion` to `CI_BUILD_NUMBER` when it exports the IPA, after the hook and after the archive. The stamp exists so the archive agrees with the upload, not to control it. Measured on run 3, which stamped `1003`: the xcarchive read `1003` and the uploaded IPA read `3`. An earlier `BUILD_OFFSET=1000` in the hook was built on the assumption that it could, and run 3 is what disproved it.
- Xcode Cloud does not gate delivery on its TEST action, so the `verify-core-tests.sh` call in `ci_pre_xcodebuild.sh` is the only test gate on TestFlight builds. Removing it leaves runs green and the gate gone.
- **An Xcode Cloud build reaches no tester group on its own.** `scripts/testflight_distribute.py` is the step that hands it over — dry-run by default, `--apply` to act, `--apply --submit` to send an external build for Beta App Review. Nothing runs it for you; that is Phase 1 step 6's deliberate choice, and forgetting it looks exactly like success. Since 2026-09-05 it is also two buttons, `Distribute iOS` and `Distribute macOS` on `ci.snowmonkey.co.uk`, one per platform because the script delivers one platform per run; see *Publishing from TeamCity*. A button is still a person pressing it.
  - **Newest means most recently uploaded, not the highest build number.** The two upload bands above make numeric order meaningless: a fresh CI build is `5` while last month's manual upload is `10001`.
  - It touches internal groups only unless `--group` names one, so no default can ever feed the public link.
  - **It also repairs the *What to Test* note**, since the hook's file is only sometimes picked up. It asks the Xcode Cloud run for the commit — a build's version is its run number — and writes `whatsNew` over the API. The test is not "is there a note" but "does the note name *this* build": the failure mode is a well-formed note about somebody else's commit, which reads as correct and describes changes the tester does not have.
  - **A locally shipped build has no run to ask, and until 2026-08-22 that meant no note at all.** Every 10000-band build reached the testers blank, `10003` included — invisible until Xcode Cloud ran out of quota and the local path stopped being the exception. The commit is knowable without the API: since task 32 `release.sh` tags the archived commit `build/N` the moment the archive exists, and `ship_commit` reads that tag first — it is the tip of `main` that was actually archived, the same fact Xcode Cloud's `sourceCommit` reports for a run, by a different route. **Builds 10001–10022 have no tag and never will**, so for them it finds the `bump to vX.Y.Z (build N)` commit by message and names the commit that bump was built from, read from its `Built-From:` trailer and from its parent only when there is none. Parentage was the whole definition until 2026-08-26, when the push learned to rebase: a reparented bump commit sits on top of whatever landed during the run, so its parent is a commit that was never archived and a note derived from it would name work the build does not contain — the same *confidently wrong* failure the dirty-tree refusal exists to prevent, and the reason the trailer existed. The tag needs neither, because the version commit is now pushed before the archive and nothing moves `HEAD` after it. Xcode Cloud is asked first and git only about numbers no run claims, because the bands collide in the low numbers: `bump to v1.0.21 (build 4)` sits in git while Xcode Cloud has its own iOS build 4. The output names which of the three answered, every time.
- **The App Store listing lives in `listing/<platform>/*.txt` and is written by `scripts/appstore_listing.py`.** Before 2026-08-22 it lived nowhere but App Store Connect, and that is the whole reason the macOS keywords kept `F1,Formula 1` for nine days after the sweep meant to remove them: the sweep edited four surfaces by hand and there was no fifth place to look. Plain text, because a description change should read as a prose diff in a commit. The tool refuses to write copy carrying the owned terms, using the same `trademark_hits` the report runs under NEEDS YOU, so a listing cannot pass one and be flagged by the other. It creates the version record, writes the four localized fields and the review detail, and attaches a build. **It never submits**, and a `READY_FOR_SALE` version is not a candidate at all, so it cannot rewrite words already on the store.
- `scripts/appstore_status.py` reads what App Store Connect holds for both platforms and writes
  nothing. Keep it that way: every API writer goes through `asc_write.Session` and requires
  `--apply`, while the report remains safe to run at any time. It is stdlib-only Python and needs no
  venv or install, and it owns the shared token signing, app lookup and build selection imported by
  the writers.
  - **Its `TESTFLIGHT` section answers "what can a tester install right now", not "does a build exist".** It walks the unexpired iOS builds newest-first asking each `?include=betaGroups` until one is in a group, and prints how far behind that has fallen — `testers can install build 4, 5 builds behind build 11`. **Being behind is never a warning.** Delivery is a manual command, so the newest build reaches nobody after every push; warning about it would leave the report permanently red and take the exit code with it. Only installing *nothing* is reported under NEEDS YOU.
- **The reader and the writers hold different App Store Connect keys, and that is the point.** The
  report runs on the Developer-level key `S394C74APG`; the App Manager key `ASC6H3SL2D` lives in
  `scripts/asc_write.py`, spelled once, and is used by `testflight_distribute.py`,
  `appstore_listing.py`, and `appstore_screenshots.py`. A Developer key reads every endpoint
  involved and is then refused the write with an empty `403` that looks like a malformed request.

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

`scripts/screenshots.py` captures the iOS ones from a simulator against fixture data, and
`scripts/mac_screenshots.py` the macOS one from the real app on this machine. Both docstrings are
the long-form reference and are kept current; what follows is the policy around them.

Both apps follow the system appearance (task 28), and the listing stays light. To look at the dark
side: `xcrun simctl ui <udid> appearance dark` before an iOS run, and `--appearance dark` on the Mac
script, which flips the desktop for the capture and puts it back.

What the dark side's first look (2026-09-05) did and did not cover: the macOS popover, Settings and
About, the iOS main screen and the Home Screen widgets were captured and read in both appearances.
The iOS About, Help and Alerts sheets, the Lock Screen widget families and the Live Activity were not,
because the sheets need a tap the simulator cannot be given from a script and the other two are the
manual cases in `screenshots.py`. They share every role with surfaces that were seen, and nobody has
yet looked at them dark on a phone.

**macOS had no tooling at all until 2026-08-22, and the listing shows it**: the only Mac image is a
1280x800 file called `Gemini_Generated_Image_utojutojutojutoj.jpg` — a picture of an idea of the
app, not the app. Guideline 2.3.3 wants screenshots of the app in use.

The Mac path is a different problem from iOS in every part except the fixture, which it imports
rather than repeats. There is no simulator, so it drives the installed app; there is no widget, so
it must launch it, and launching starts a fetch that overwrites the fixture; and the popover is
opened by a System Events click, which needs Accessibility. Two refusals came directly out of the
first two runs and are the reason it is trustworthy:

- **It checks the app it is about to photograph is the build this checkout makes.** The first run
  captured the installed `1.0.21` — the last release, from before the 4.1(a) sweep — and produced a
  flawless screenshot of the owned wordmark in the menu bar and again in the popover header, with
  every step reporting success. That is the asset three Copycats rejections were about.
- **It refuses to run with the feed reachable** unless `--allow-network` says otherwise, because the
  app refetches on launch and again when the popover opens, so the picture is of today rather than
  of the fixture. With the network off the fetch throws, `performRefresh` keeps the published state,
  and the capture reproduces.

**How it knows which data it photographed is the app's own log, not the cache file.** Reading the
cache back was the first design and it was wrong on both runs — once because the fetch had not
finished writing when it looked, and once because the app was running from a path where the save to
the group container failed, so the screen held live data the disk never received. `ScheduleStore`
logs `refresh complete` or `refresh failed` on the `store` channel, and that is a fact the app
states rather than one to infer. Same pattern as `alerts_check.py`, attached before launch for the
same reason.

The capture is a region of the real screen anchored to the top-right, so it contains the menu bar,
the popover hanging off it, and whatever is behind them. Set a plain desktop picture first. A
1280x800 point region lands as 2560x1600 on a Retina Mac, and App Store Connect accepts both.

```
scripts/screenshots.py --device "NoSpoilers-iPhone-65" --expect 1242x2688 --widget-size large
```

`--device` is repeatable. Project work always passes one of the owned names below, never a stock
device name or raw UDID. A name matching more than one simulator is refused rather than guessed;
`--dry-run` prints the plan and touches nothing.

- **Always name a simulator this project owns, never a stock one.** Other projects run on this
  machine and share the stock devices, and a capture is not read-only: it writes an App Group
  fixture, reinstalls the app, rewrites SpringBoard's layout, and reboots. Doing that to a shared
  `iPhone 11 Pro Max` corrupts whatever else was relying on it, and their runs corrupt ours. Own one
  simulator per device size the work needs:
  - `NoSpoilers-iPhone` and `NoSpoilers-iPad` for ordinary verification
  - `NoSpoilers-iPhone-65` for the 1242x2688 iPhone listing slot
  - `NoSpoilers-iPad-129` for the 2048x2732 iPad listing slot

  Recreate a missing device with the current runtime id:

  ```sh
  xcrun simctl create "NoSpoilers-iPhone" com.apple.CoreSimulator.SimDeviceType.iPhone-17 <runtime>
  xcrun simctl create "NoSpoilers-iPad" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB <runtime>
  xcrun simctl create "NoSpoilers-iPhone-65" com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max <runtime>
  xcrun simctl create "NoSpoilers-iPad-129" com.apple.CoreSimulator.SimDeviceType.iPad-Air-13-inch-M4 <runtime>
  ```

- **Screenshots are taken against a fixture, never the live calendar**, so the same command produces
  the same picture in March and in August. Out of season the widget correctly renders its off-season
  state, and mid-season it renders whichever race happens to be next; neither is a listing asset.
  The fixture offsets are relative to run time and must stay that way.
- **Bootstrap a newly created simulator before its first capture.** Launch the app once, let it
  settle, then terminate it so WidgetKit registers the extension. Without that one launch,
  SpringBoard drops the widget and the script's supported-family diagnosis is misleading. The
  capture script re-seeds afterwards, so the bootstrap cannot leave live data in the image.
- **After bootstrap, never launch the app to make it pick up the fixture.** `ScheduleStore.refresh()` saves the
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
  `chronod`, and deleting `chrono.sql` were all tried and none of them work. If this is a fresh
  simulator, complete the one-time app-launch bootstrap before the install-and-capture run.
- **Pick the device *type* by the pixel size the listing slot accepts, not by what is newest**, and
  pass `--expect` so a wrong one fails in seconds rather than at upload. An `iPhone 11 Pro Max` is
  natively 1242 × 2688 and accepted; an `iPhone 17 Pro Max` at 1320 × 2868 is refused. Create the
  project-owned simulator from the accepted device type — the model is the constraint, the name is
  ours to choose.
- **A blank or stale widget still exits 0 with a valid PNG.** `--expect` checks pixel dimensions and
  `confirm_widget_size()` checks the layout entry survived; neither can tell you the widget rendered
  real content. Both failures were seen on 2026-08-13 and both look like a successful run. **Look at
  the picture before uploading it** — that is the check, and there is not a scripted substitute.
- **Do not widen `SETTLE_SECONDS` to make a grey capture come good.** Grey bars are the redacted
  placeholder, still on screen because the timeline is not built yet. Building a whole season's
  worth took 3–6 seconds — longer than SpringBoard waits — until the horizon capped it at ~0.35s,
  so a grey capture now means something has regressed. Widening the delay hides that on the one
  machine that takes screenshots and leaves it in front of every user.
- Two runs with no code change are **not** byte-identical and cannot be — the countdowns advance and
  the status-bar clock moves. Expect them to differ only in those.
- **Keep `INFOPLIST_KEY_CFBundleDisplayName` set on the iOS target.** Without it the Home Screen name
  falls back through `PRODUCT_NAME` to `TARGET_NAME` and reads `NoSpoilersApp`. Only a widget
  screenshot shows this, because only the widget puts the containing app's name on screen; it was
  found this way in `7d64a1b` and would otherwise have shipped.

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

**Two deliveries, independent of each other, since 2026-09-10** (task 38). Neither waits for the
other, neither's prerequisites are asserted by the other, and their version and build numbers need
not match.

**Xcode Cloud is gone, removed on 2026-09-09.** It archived and uploaded on every push
to `main`, and it asked none of the four questions `release.sh` asks first — so when 1.1.3 was
approved on 2026-09-07 and its train closed, it went on uploading 1.1.3 and Apple refused each one
by email (`ITMS-90186`, `ITMS-90062` on run 125). Nothing watched it and nothing announced it.

Its quota had also run out once before, on 2026-08-22: runs 33, 34 and 35 were each cancelled 5–8
seconds after creation with `startedDate: None` and no `cancelReason`, and `POST /v1/ciBuildRuns`
answered `500`. A push produced a run that went away and the app record simply stopped gaining
builds. It reset on 2026-09-05, silently, which is how it came back without anyone deciding it
should.

- **TestFlight, both platforms, is `scripts/submit_build.py`**, the one Apple delivery path. A person
  runs it, and TeamCity's `Ship` runs it behind `scripts/ci-publish.sh`. It is FunMax's
  `submit_build.py` in shape, because that one has delivered unattended from the same agents while
  every press of the old combined button stopped before archiving. In order, and all before anything
  is built:
  - **It refuses a tree that is not exactly a commit on `origin/main`.** Dirty, because
    `xcodebuild archive` builds the tree and the tag and note would name something else. Not on
    `origin/main`, because the `build/N` tag has to mark a commit every clone can reach. Being behind
    the tip is fine and is the ordinary TeamCity case: a revision is pinned when a build is queued,
    and that verified revision is what ships. **It never commits, rebases or pushes a branch**, so
    the archived commit is the verified commit.
  - **It refuses a closed train, per platform**, with `appstore_status.closed_train`, and names the
    two commands that record the approval and open the next version. A closed train on one platform
    does not stop the other.
  - **It runs `scripts/verify-core-tests.sh`** unless `--tested` says the caller verified this exact
    commit — which only `Ship` passes, beside its snapshot dependency on `Verify`.
  - **It reserves the build number by pushing `build/N` before archiving.** N is
    `_version.sh: next_build_number`: the highest build App Store Connect holds on either platform —
    every page, expired builds included — or the highest `build/` tag, plus one. The tag push is the
    lock: two runs that chose the same N cannot both hold it, and the loser chooses again in seconds
    rather than colliding at upload. **Every tag carries a `Reservation:` line of its own, and origin
    is read back after the push**, because without one two runs tagging one commit as one person in
    one second wrote identical tag objects and both pushes succeeded. `release.sh` reserves the same
    way. A reserved number that never reaches Apple is harmless. A two-platform run is one number and
    two uploads.
  - Then **for iOS, then macOS**: a Release archive with `CURRENT_PROJECT_VERSION=N` on the command
    line; a check that every `.app` and `.appex` reads N and the project's version, because an app
    whose widget extension disagrees is refused at upload; and one authenticated `-exportArchive`
    with `method=app-store-connect`, `destination=upload`, `signingStyle=automatic`,
    `uploadSymbols=true` and **`manageAppVersionAndBuildNumber=false`** — its default is YES, and
    Xcode would renumber the build on the way out. Apple's tools run with `/usr/bin` first on PATH.
  - **It waits for Apple, bounded at an hour per platform**, and says so when an upload has not
    appeared after fifteen minutes, since a binary refused on arrival never appears and is explained
    by email. A 429, a 5xx or a dropped connection during the wait is one more poll; any other
    refusal ends that platform's wait.
  - **It delivers exactly the build it uploaded**, within ten minutes: `testflight_distribute.py
    --platform P --build N --apply`, never "the newest". That writes the note from the `build/N` tag,
    adds the build to the internal group — settling Apple's 422 for a build it attached itself — and
    reads both back, exiting 1 unless the group holds it and the note's `Build N from <sha>` line
    names the commit the tag marks. A note naming the right number from another commit is rewritten,
    not accepted.
  - **It leaves a record**, `no-spoilers-ship/build-N/record.json` under the temporary directory (a
    `Ship` artifact), naming the commit, the number and how far each platform got. **Whatever stops a
    platform is recorded against the stage it was in, and the next platform still runs.** When an
    upload was accepted and the wait or delivery then failed, the record and the log name the recovery,
    `testflight_distribute.py --platform P --build N --apply`, which delivers that recorded build and
    cannot relabel a newer one. Uploading again would only be refused as a duplicate.
  - `--archive-only` archives and exports locally and uploads nothing, and on macOS checks the
    package's installer signature: the way to prove signing without spending a number.
  - **Final App Review submission is a person pressing Submit.** Nothing here submits.
- **A version is opened by `scripts/open-version.sh X.Y.Z`**, and by nothing that archives. It sets
  `MARKETING_VERSION` in every configuration, commits `open vX.Y.Z` and pushes it, refusing a dirty
  tree, a checkout that is not exactly `origin/main`, and a version that does not move forward or
  that a tag already claims. That commit is verified and shipped like any other.
- **Homebrew is `scripts/release.sh`**, through `scripts/ship-homebrew.sh` on a laptop or
  `ci-publish.sh --platform homebrew` on an agent: the Developer ID zip, notarization, a GitHub
  release and the cask. **It releases the version the commit holds** and changes nothing on `main`:
  until 2026-09-10 it set `MARKETING_VERSION` to whatever it was given and pushed that, which on its
  own cadence would walk the project back under the Apple train. It refuses a commit not on
  `origin/main`, runs the gate, and reserves `build/N` before archiving exactly as
  `submit_build.py` does, so the two cannot stamp one number on two builds. It has no TeamCity
  configuration yet.
- **What went, on 2026-09-10, and why.** `scripts/ship.sh`, `ship-ios.sh` and `ship-appstore.sh`,
  `release.sh`'s `app-store` and `both` channels, `_version.sh: version_to_ship`, and
  `NoSpoilers/ExportOptions-AppStore.plist` with its deprecated `app-store` method. Every press of
  the combined button was refused before archiving by two prerequisites only Homebrew needed; a
  Homebrew failure after the Mac upload would have ended the run before iOS; the version commit was
  pushed with a rebase after the test gate, so the archive could differ from the verified commit;
  and an upload was the finish line, with delivery a second button.
- **There was a `.github/workflows/release.yml` claiming to do the Developer ID channel on a `v*` tag. It was deleted on 2026-08-12 because it had never worked — ten tag pushes since March, ten failures, each dying in about twelve seconds importing a certificate from `secrets.DEVELOPER_ID_CERT_P12`, which was never set. The repository has no secrets at all.** It was a duplicate of what `ship.sh` already does locally, so nothing was lost, and every release you have ever shipped went out from a laptop. What it cost was worse than nothing: a red cross on every release tag, teaching everyone that a failed run on a release is normal.

### Shipping from TeamCity

**`Ship` is TestFlight delivery.** One step, `scripts/ci-publish.sh --platform %ship.platform%
--tested %ship.args%`. `ship.platform` is `all` by default — iOS then macOS under one number — or
`ios` or `macos`; `ship.args` takes `--check` or `--archive-only`, and both go back to their defaults
after a custom run. It takes the **write** lock on `no-spoilers-xcode`, where the two Xcode
verification legs take read locks; it has a snapshot dependency on `Verify` with
`reuseBuilds = SUCCESSFUL`, which is what makes `--tested` true; one run at a time; 360 minutes,
above `submit_build.py`'s own worst case of 330 so that the script and not TeamCity ends a slow run
and records why, which `submit_build.py --selftest` checks against this file; and
it publishes the run's record and the export's `.xcdistributionlogs`, which hold Apple's verbatim
answer when signing or an upload is refused.

**It has no trigger until it has delivered once, end to end.** Decided 2026-09-10: like FunMax's
`Ship`, it then follows every successful `Verify`, the nightly included — so an unchanged week spends
seven numbers and puts seven builds in front of the internal testers, which is the accepted trade for
a daily answer.

**`ci-publish.sh` is deliberately thin.** It asserts what a build agent breaks and the engines
assume, in seconds, before anything expensive, and then hands over. For an Apple platform: that
*Apple Distribution* can **sign** a throwaway binary (a locked login keychain lists identities
happily and then refuses), that the *Mac Installer Distribution* identity is present for macOS, that
both App Store Connect keys are there, and that the checkout can push a tag over SSH with an author.
For `homebrew`: *Developer ID Application* by probe, `notarytool history` as a read that proves the
notarization key, `gh auth status`, and a fresh clone of `homebrew-tap` under the build's own temp
directory with a `push --dry-run`. `--check` reports every gap in one run rather than one per press,
and for an Apple platform then runs `submit_build.py` without `--apply`, which asks App Store Connect
everything a real run would and changes nothing. A missing certificate prints the identities the
agent does hold.

The `.app` on both platforms is signed with *Apple Distribution*; the Mac App Store `.pkg` with *Mac
Installer Distribution*; the Homebrew zip with *Developer ID Application*, notarized. An identity
installed for the `nickpomfret` user reaches all three agents, and only a build step can prove the
agent's session can use it.

**The five verification configurations still hold no credential and must not gain one.** `Ship`
is separate and holds them.

**`Ship` is defined in `.teamcity/settings.kts`, and so is every other configuration this
project has.** Versioned settings are authoritative: a project synchronised against a DSL that
omits a configuration *deletes* that configuration, so the file has to describe the whole project
or none of it. The four verification configurations and `TestFlight` existed in the UI first and
were **read back over the REST API before the DSL was written** — steps, triggers, shared-resource
locks, agent requirements and every snapshot-dependency flag — rather than reconstructed from what
they look like from outside. `scripts/teamcity.py settings` is that read, and
`snowmonkey-proxy-common`'s `TEAMCITY-AGENTS.md` §10 is the access it needs.

**Live since 2026-09-09**, and the conversion was verified rather than assumed: the server's
settings were read over REST before and after and compared field by field — five configurations,
**zero differences**, nothing lost, `Ship` added, and build history intact at #92. The uuids in
the DSL are what preserved that history; without them TeamCity can treat a configuration as new,
delete the old one and restart its counter.

Two things to know when editing it. **A DSL that fails to compile is reported and the current
settings are left alone** — but synchronization then *stops* rather than retrying, and
`POST /app/rest/projects/id:NoSpoilers/versionedSettings/loadSettings` restarts it.
**`versionedSettings/status` returns every compile error with file and line**, where
`teamcity-versioned-settings.log` returns the first and "and N more errors"; use the endpoint.

**Versioned settings are also the only backup those configurations have.** `TEAMCITY.md` §2 and
§3: what a project keeps in its own `.teamcity/` survives the server, what is configured in the UI
does not, and the box has no backups of either TeamCity volume. A `settings.kts` that fails to
compile explains itself in `teamcity-versioned-settings.log` inside the `teamcity-logs` volume —
not in `docker logs`, and not in Loki.

**`TestFlight` is the recovery button.** Two steps, `python3 scripts/testflight_distribute.py
--platform ios --apply %distribute.args%` and then `macos`, the second run even when the first fails.
When `Ship` uploaded a build and could not finish delivering it, press this with `distribute.args`
set to `--build N` from the run's record; without it the script takes the newest upload. It also
takes `--group <name>` or `--submit`. It reads back what it wrote and is red unless the group holds
the build and its note names it. No snapshot dependency and no lock, because nothing compiles.

- **Xcode Cloud built this app from 2026-08-08 to 2026-09-09 and no longer does.** It archived both schemes on every push to `main`, uploaded both, and is the origin of every build numbered 1 to 125 on the record. Removed with it: the workflow, the `NoSpoilers/ci_scripts/` hook, `scripts/ci_health.py`, the `ciProducts` lookups, and `set_build_number`, whose only caller the hook had become. What it cost on the way out: it asked none of `release.sh`'s four questions, so once 1.1.3 was approved on 2026-09-07 it went on uploading that closed train on every push — `ITMS-90186` and `ITMS-90062` by email each time, up to run 125 — until the emails were noticed and `MARKETING_VERSION` was moved to 1.1.4.
  - Two of its lessons are load-bearing elsewhere and are kept where they apply, not here: the `10000` band below exists because its run numbers and `release.sh`'s counter had to not collide, and `verify-core-tests.sh` runs inside `release.sh` because that gate lived only in the hook until 2026-08-22 and left the path entirely when Xcode Cloud stopped.
  - The rest is history and is in git: that `GET /v1/ciProducts` is a cache which lies in both directions; that Integrate → Create Workflow seized the sibling project's product three times between 2026-08-08 and 2026-08-12, renaming it and repointing it, invisibly from the victim's side; that a product must therefore be found by the app it builds and never by its name; and that deleting and recreating one restarts `CI_BUILD_NUMBER` at 1 against numbers already spent, which does not fail the build — it goes green and dies by email.
- **The two upload paths are kept apart by the `10000` band.** `release.sh` counted up from a committed `CURRENT_PROJECT_VERSION` of `10000` until 2026-09-05 (10001 … 10022, one step per ship run rather than one per platform), and since 2026-09-05 takes the next number from App Store Connect itself — the highest build the record holds on either platform, plus one — so the band continues from wherever the record is without a file remembering it. Xcode Cloud uses its run number. The committed value is frozen at `10022` and is not a build setting the archive reads; do not lower it, because a local Xcode build stamps it into a bundle and build numbers only ever increase. **The separation has been observed on the real app record**, measured 2026-08-16: the macOS 1.1.1 train holds `10001` beside Xcode Cloud's 15, 16 and 17, and the iOS 1.1.1 train holds `10002` beside its 1 through 17. Nothing collided. The current `release.sh` has since shipped the iOS channel twenty times and the macOS App Store channel once (`10006`, 2026-08-23). **The first three-channel `ship.sh` run since the rewrite went out on 2026-09-09**: 1.1.4, build 10024, `build/10024` on `ba243f1`, the GitHub release `v1.1.4` and the cask bumped to 1.1.4 — the Developer ID channel's first run under this engine, and the first time one number reached all three channels rather than one per platform.

- **Three tag families, since 2026-09-05, and each means one thing.** Before it there was one, `vX.Y.Z`, written at the *first* upload of a train, which is not the build users got: `v1.1.2` marks `bump to v1.1.2 (build 10003)` and the build on sale is 10012. Those bare tags are left where they are — the Homebrew cask and the GitHub releases point at them — and mean "first upload of that train". Four of them did not, and were deleted on 2026-09-09: `v1.1.2` and `v1.1.3`, written by that old rule at an *App Store* upload and never released through the Developer ID channel — left in place they would have been silently reused by `tag_version`, which skips a name that already exists — and `v1.0.10` and `v1.0.11`, two gaps in the dense run of releases made on 2026-03-29. **The invariant that leaves is worth keeping: every bare `vX.Y.Z` tag has a GitHub release of the same name, and every release has its tag — 22 of each, checked 2026-09-09.** A bare tag with nothing behind it is now a defect, not history. The family ends at `v1.1.1` (2026-08-12), the last Developer ID release. Going forward:
  - `build/N` — build number N was reserved for an archive of this commit. One per run of `submit_build.py` or `release.sh`, annotated, **pushed before the archive**, because the push is what makes the number that run's. A number reserved and never uploaded is harmless; the run's record says which platforms reached App Store Connect. A second run on an unchanged commit reserves a new number and puts a second tag on the same commit.
  - `ios/vX.Y.Z` and `macos/vX.Y.Z` — the build of X.Y.Z Apple approved for that platform, on that build's commit. Written by `scripts/tag_approved.py PLATFORM VERSION --apply`, which asks `appstore_status.py --approved` for the build number and `ship_commit` for its commit (`build/N`, or the bump commit for 10001–10022). Two names because the platforms are approved at different builds — iOS 1.1.2 at 10012, macOS 1.1.2 not yet submitted. A person runs it once Apple approves; `submit_build.py`'s closed-train refusal names it, beside `open-version.sh`. It never moves a tag: one already on the right commit is kept, one on a different commit stops the run.
  - `vX.Y.Z` — the macOS Developer ID release, that channel only, annotated. Kept under the bare name because the cask downloads `releases/download/v#{version}/…`. The App Store channels no longer tag a version at upload.
  - `suggest_next_version` reads all three version families, so a version approved on the store under `ios/` is not offered again. **Tags have to be fetched wherever they are read** — a TeamCity checkout carries none — and `next_build_number`, `submit_build.py`, `release.sh`, `testflight_distribute.py` and `tag_approved.py` each fetch before asking.
  - **`suggest_next_version` opens the *next* train, and nothing ships with it.** It takes the highest version anything claims — tags or `MARKETING_VERSION` — and steps past it, which is the version to open once a train has closed. Until 2026-09-10 `version_to_ship` chose between it and the project's own version for `ship.sh` and `ci-publish.sh`; now nothing that archives chooses a version at all. `submit_build.py` ships the committed version or refuses a closed train, and names `open-version.sh` with this function's answer.

- **The cost of the bands is that the newest build looks missing in TestFlight.** TestFlight orders builds by number within a version train, so a `10000`-band build outranks every Xcode Cloud build in that train permanently. Observed 2026-08-17: iOS 1.1.1 read `[10002, 18, 17, … 1]` with `10002` uploaded 12 August and `18` uploaded 16 August — the newest build four days newer and nineteenth in the list. macOS 1.1.1 was the same shape. Nothing is broken and testers can install the newest build; it just is not where anyone looks for it.

- **Raising `CURRENT_PROJECT_VERSION` could never fix that ordering.** Xcode Cloud rewrote `CFBundleVersion` to `CI_BUILD_NUMBER` when it exported the IPA — after its hook and after the archive — so its builds were 19, 20, 21 whatever the project said. Run 3 proved it: the xcarchive read `1003` and the uploaded IPA read `3`. An earlier `BUILD_OFFSET=1000` in the hook assumed otherwise. Kept because it is why the committed value is a ledger rather than a lever.

- **What does fix it is opening a new train**: bump `MARKETING_VERSION`. A fresh train contains no `10000`-band build, so the next Xcode Cloud run is top of its own group. Done on 2026-08-17, 1.1.1 → 1.1.2, with `CURRENT_PROJECT_VERSION` left at `10002`. The catch: shipping that train with `release.sh` puts `10003` into it and the problem returns — which is what happened on 2026-08-22, Xcode Cloud having no quota left to put anything above it. Tidying an existing train means expiring the `10000`-band builds in App Store Connect, which is a browser action — `scripts/appstore_status.py` is GET-only by design.
- No CI script can influence the build number that reaches App Store Connect: Xcode Cloud rewrites `CFBundleVersion` to `CI_BUILD_NUMBER` when it exports the IPA, after the hook and after the archive. The stamp exists so the archive agrees with the upload, not to control it. Measured on run 3, which stamped `1003`: the xcarchive read `1003` and the uploaded IPA read `3`. An earlier `BUILD_OFFSET=1000` in the hook was built on the assumption that it could, and run 3 is what disproved it.
- **An uploaded build reaches no tester group on its own**, whichever path uploaded it. `scripts/testflight_distribute.py` is the step that hands it over — dry-run by default, `--apply` to act, `--apply --submit` to send an external build for Beta App Review, and `--build N` to hand over a named build rather than the newest upload. **Since 2026-09-10 `submit_build.py` runs it, always with `--build N`**, and the `TestFlight` button runs it for recovery; see *Shipping from TeamCity*.
  - **Newest means most recently uploaded, not the highest build number.** The two upload bands above make numeric order meaningless: a fresh CI build is `5` while last month's manual upload is `10001`.
  - It touches internal groups only unless `--group` names one, so no default can ever feed the public link.
  - **It also repairs the *What to Test* note**, since the hook's file is only sometimes picked up. It asks the Xcode Cloud run for the commit — a build's version is its run number — and writes `whatsNew` over the API. The test is not "is there a note" but "does the note name *this* build": the failure mode is a well-formed note about somebody else's commit, which reads as correct and describes changes the tester does not have.
  - **A locally shipped build has no run to ask, and until 2026-08-22 that meant no note at all.** Every 10000-band build reached the testers blank, `10003` included — invisible until Xcode Cloud ran out of quota and the local path stopped being the exception. The commit is knowable without the API: since 2026-09-05 `release.sh` tags the archived commit `build/N` the moment the archive exists, and `ship_commit` reads that tag first — it is the tip of `main` that was actually archived, the same fact Xcode Cloud's `sourceCommit` reports for a run, by a different route. **Builds 10001–10022 have no tag and never will**, so for them it finds the `bump to vX.Y.Z (build N)` commit by message and names the commit that bump was built from, read from its `Built-From:` trailer and from its parent only when there is none. Parentage was the whole definition until 2026-08-26, when the push learned to rebase: a reparented bump commit sits on top of whatever landed during the run, so its parent is a commit that was never archived and a note derived from it would name work the build does not contain — the same *confidently wrong* failure the dirty-tree refusal exists to prevent, and the reason the trailer existed. The tag needs neither, because the version commit is now pushed before the archive and nothing moves `HEAD` after it. Xcode Cloud is asked first and git only about numbers no run claims, because the bands collide in the low numbers: `bump to v1.0.21 (build 4)` sits in git while Xcode Cloud has its own iOS build 4. The output names which of the three answered, every time.
- **The App Store listing lives in `listing/<platform>/*.txt` and is written by `scripts/appstore_listing.py`.** Before 2026-08-22 it lived nowhere but App Store Connect, and that is the whole reason the macOS keywords kept `F1,Formula 1` for nine days after the sweep meant to remove them: the sweep edited four surfaces by hand and there was no fifth place to look. Plain text, because a description change should read as a prose diff in a commit. The tool refuses to write copy carrying the owned terms, using the same `trademark_hits` the report runs under NEEDS YOU, so a listing cannot pass one and be flagged by the other. It creates the version record, writes the four localized fields and the review detail, and attaches a build. Since 2026-09-06 it can also **rename** the one version in preparation (`--version 1.1.3 --rename`), because App Store Connect allows one per platform and refuses a second: the macOS 1.1.2 record opened on 2026-08-22 was never submitted, the project had moved on to 1.1.3, and the record's version string is the only thing about it that has to change. **It never submits**, and a `READY_FOR_SALE` version is not a candidate at all, so it cannot rewrite words already on the store.
- `scripts/appstore_status.py` reads what App Store Connect holds for both platforms and writes
  nothing. Keep it that way: every API writer goes through `asc_write.Session` and requires
  `--apply`, while the report remains safe to run at any time. It is stdlib-only Python and needs no
  venv or install, and it owns the shared token signing, app lookup and build selection imported by
  the writers.
  - **Its `TESTFLIGHT` section answers "what can a tester install right now", not "does a build exist".** It walks the unexpired builds newest-first asking each `?include=betaGroups` until one is in a group, and prints how far behind that has fallen — `testers can install build 4, 5 builds behind build 11`. **Being behind is never a warning**: a build sits in no group for the minutes it spends processing, and a warning that fires during every delivery is one nobody reads. Only installing *nothing* is reported under NEEDS YOU.
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

Both apps follow the system appearance (since 2026-09-05), and the listing stays light. To look at the dark
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
the popover hanging off it, and whatever is behind them. Set a plain desktop picture first. Or pass `--mask` (2026-09-06): it keeps the status item and the popover, both read from Accessibility, and paints a plain ground over the rest — a plain desktop turned out not to be something this machine could simply be given, and the 1.1.3 listing images were made this way. A
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

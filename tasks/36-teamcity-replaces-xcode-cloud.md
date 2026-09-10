# Task 36: TeamCity replaces Xcode Cloud

**Status: IN PROGRESS. Raised 2026-09-09. Xcode Cloud is off and out of the repository. The
`Ship` button now exists on TeamCity and the whole project is versioned settings in
`.teamcity/settings.kts` — verified against the server as 0 field differences on the five
existing configurations, with build history intact. The button has been pressed twice, and the
preflight stopped every press in seconds. What is outstanding is two certificates on the agent:
the notarization key and `gh` were proven by `Ship #3`, and the tap is cloned by every run. Until
those exist the button cannot get past its own preflight, and a
release is a `scripts/ship.sh` run on a laptop, which is how 1.1.4 went out on 2026-09-09.
The one thing the presses did settle is the question this whole file was written around: the
agent's login keychain is unlocked in its own session, and the certificate it holds can sign.**

**Scope decided 2026-09-09: option A — one button, all three channels.** Modelled on
`SuperFunMaxMusic_Ship`, which is one Command Line step (`submit_build.py --apply --tested`) behind
a snapshot dependency on its verification composite. The alternative considered and rejected was a
`Publish` button per platform: each press asks App Store Connect for the next build number and gets
a different one, so one version would ship as two builds — the 1.1.1 / 10001 / 10002 defect
`ship.sh` exists to prevent — and a third from the laptop for Homebrew. See *One button* below.

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

## One button

**A release is one marketing version and one build number across three channels.** That is the
property `ship.sh` exists to hold, and a platform at a time cannot hold it: `ci-publish.sh` asks
App Store Connect for the next number on every invocation, so two presses produce two numbers for
one version. 1.1.1 is build 10001 on macOS and 10002 on iOS for exactly that reason.

So `--platform all` does not orchestrate the platforms itself. It asserts the machine and then
hands over to `ship.sh`, which already picks the version once, picks the number once, and runs
macOS `--channel both` (App Store, then Developer ID from the same archive) followed by iOS. The
Homebrew channel rides inside that macOS run, which is what makes the build number *shared* rather
than merely equal. Nothing here is a second release engine, and `release.sh` is still the only one.

## The blocker, and it is not a code one

**Everything outstanding is a credential on the agent.** The agent is `teamcity-agent-3`, running
as `nickpomfret`, and it holds an *Apple Distribution* certificate and nothing else — which is why
`Publish iOS` covered one platform.

| What | For | State |
|---|---|---|
| *Apple Distribution* | the `.app`, both platforms | present, and proven to **sign** in the agent's own session 2026-09-09 |
| *Mac Installer Distribution* | the Mac App Store `.pkg` | **missing** |
| *Developer ID Application* | the Homebrew zip | **missing** |
| `AuthKey_ASC6H3SL2D.p8` reaching the notary service | notarization | **proven 2026-09-09** — `notarytool history` authenticated |
| `gh auth status` | the GitHub release | **proven 2026-09-09** |
| `homebrew-tap` to commit the cask to | the cask commit | **not an agent prerequisite** — every run clones it fresh, since 2026-09-10 |

Nothing in this repository can create any of them. Each is asserted by `ci-publish.sh --check`
before anything is built, and one `--check` run names every gap rather than one per press — which
took two presses and a fix to become true; see *Every gap in one press*.

The three identity strings in `ci-publish.sh` were conventions written by hand — a team name and a
team id — never compared with the keychain that would be used. **Settled 2026-09-09**: the agent
holds `Apple Distribution: Nick Pomfret (6FZN56WC8G)` under exactly that spelling, so the two
missing strings, which differ from it only in certificate type, are right too.

## The plan

1. **Restore the CI entry point as `scripts/ci-publish.sh`**, recovered from
   `e08e838^:scripts/ci-publish-ios.sh` and generalised from one platform to a required
   `--platform ios|macos`. Keeps its assertions, its `--check` mode, and its rule for
   choosing a version. Still thin: `release.sh` remains the only engine.
2. **Add the macOS assertion** — the installer identity — so the macOS button fails in
   seconds with what is missing rather than after an archive.
3. **Remove Xcode Cloud from the repository** (detail below).
4. **TeamCity configuration**, in the existing `NoSpoilers` project, as versioned settings —
   `.teamcity/settings.kts` and `.teamcity/pom.xml`, the shape FunMax uses.

   ### The whole project, because it has to be

   **Versioned settings are authoritative: a project synchronised against a DSL that omits a
   configuration loses that configuration.** So the file describes the whole project or none
   of it — the four verification configurations, `TestFlight`, and `Ship`.

   **That is also why this is worth doing for its own sake, separately from the button.**
   `TEAMCITY.md` §2: *"Projects that use versioned settings keep their build configurations in
   their own repo's `.teamcity/`, so those survive the server. Anything configured in the UI
   does not."* And §3: **there are no backups** — no cron entry, no `/opt/backups`, and
   `deploy.sh` does not touch the volumes, so a lost volume loses the database and every
   UI-configured setting. Until this lands, the only copy of those five configurations is on
   that box.

   **It was written from the server's own record, not from inference.** An earlier draft of
   this section claimed the existing configurations could not be read from outside and that
   `Ship` therefore needed a project of its own. That was wrong, and the thing that made it
   wrong is documented: `TEAMCITY-AGENTS.md` §10 in `snowmonkey-proxy-common` gives an
   authenticated REST path to the server, and the shared CLI already uses it. What was missing
   was a query for what a configuration *is* rather than how its last build went — a build log
   shows the steps, and steps are the smallest part of it. That query now exists as
   `scripts/teamcity.py settings`, added to the plugin in `npomfret/agent-standards`.

   Read back before the DSL was written, and reproduced in it exactly:

   | | |
   |---|---|
   | VCS root | `NoSpoilers_Main`, anonymous HTTPS on `refs/heads/main`; referenced as `DslContext.settingsRoot` rather than declared, since turning versioned settings on makes it read-only |
   | Project feature | SharedResources `no-spoilers-xcode`, quoted, quota 3, id `PROJECT_EXT_4` kept so the resource is not deleted and recreated |
   | `Verify: Python` | `./scripts/verify-python-selftests.sh`; requires `python3.executable`; no lock |
   | `Verify: Xcode` | three steps, mac/ios/widget; **read** lock; requires `tools.xcode.home` |
   | `Verify: Swift tests` | `./scripts/verify-core-tests.sh`; **read** lock; requires `tools.xcode.home` |
   | `Verify` | no steps; VCS trigger on `NoSpoilers/**`, `NoSpoilersCore/**`, `scripts/**`, per-check-in, quiet period `DO_NOT_USE`; nightly 00:00 Europe/London with `withPendingChangesOnly = false`; three snapshot dependencies at `ADD_PROBLEM` / `MAKE_FAILED_TO_START` / `ReuseBuilds.NO` |
   | `TestFlight` | two steps, the macOS one `ExecutionMode.ALWAYS`; `distribute.args` empty |

   `env.TMPDIR = %system.teamcity.build.tempDir%` on every configuration except `TestFlight`,
   which does not have it — reproduced as it is rather than tidied.

   ### `Ship`

   - **One step**: `scripts/ci-publish.sh --platform all %ship.args%`. `ship.args` empty by
     default and **put back empty afterwards**: `publish.args` left holding a stale value is
     how four presses uploaded a closed train on 2026-09-05.
   - **The write lock on `no-spoilers-xcode`**, where the two Xcode legs take read locks. It
     archives twice; no compile runs beside a release and no release beside a compile.
   - **Snapshot dependency on `Verify`**, `CANCEL` on failure, `reuseBuilds = SUCCESSFUL`.
     Unlike `TestFlight` it archives, so it must build a revision that passed — and unlike the
     chain's own dependencies it *should* reuse, because the point is to ship a commit already
     proved rather than to prove it again.
   - **No trigger**, which is the decision at the top of this task rather than an omission.
   - **`maxRunningBuilds = 1`**, and a 120-minute timeout.

   **The five verification configurations still hold no credential and must not gain one.**
   One file does not change that; it makes it checkable in one place.

   ### Enabling it

   `NoSpoilers` → **Versioned Settings** → VCS root `NoSpoilers_Main`, format **Kotlin**,
   *Store secure values outside of VCS* on, synchronisation enabled, **allow UI editing off**
   (§8, otherwise the server drifts from the repo). The enable dialog asks which side wins;
   this repo now has a `.teamcity/settings.kts` written to match the server, so either answer
   should be a no-op — but **"overwrite VCS with the current settings" is the safe answer**,
   because it is the one that cannot lose anything if the DSL is wrong somewhere.

   **A `settings.kts` that fails to compile explains itself in
   `teamcity-versioned-settings.log`** (`TEAMCITY.md` §6), which is a file in the
   `teamcity-logs` volume and reaches neither `docker logs` nor Loki:

   ```
   ssh root@snowmonkey.co.uk "tail -50 /var/lib/docker/volumes/snowmonkey-proxy_teamcity-logs/_data/teamcity-versioned-settings.log"
   ```

   ### Enabled 2026-09-09, and what it cost to get there

   **Done.** `synchronizationMode=enabled`, format kotlin, root `NoSpoilers_Main`,
   `buildSettingsMode=ALWAYS_USE_CURRENT`, secure values outside VCS. TeamCity set
   `useRelativeIds=true` itself on switching to Kotlin, which was the one thing that could
   not be checked beforehand and the thing the external ids depended on.

   **The result, measured rather than assumed.** `teamcity.py settings --json` before the
   change and again after, compared field by field across name, description, type,
   parameters, steps, triggers, features, agent requirements, dependencies and VCS roots:

   > 5 configurations compared, **0 field differences**. Lost: none. New: `NoSpoilers_Ship`.

   Build history survived — `Verify` and its three legs still read **#92**, not #1 — which is
   what the uuids were for.

   **It took three attempts, and both failures were mine.** A DSL that does not compile is
   reported and the current settings are left alone, so nothing was ever damaged.

   1. `Unresolved reference: sharedResources`. I had added
      `import ...buildFeatures.sharedResources`. FunMax uses `sharedResources { }` with **no
      such import** and compiles; the symbol comes from the wildcard, and naming it
      explicitly breaks it and every use with it. I had checked that FunMax used the
      construct, not that it used it without the import.
   2. `Unresolved reference: MAKE_FAILED_TO_START` (×3) and `VcsTrigger`. Both were REST
      property *values* copied into the DSL as if they were constants. `FailureAction` has no
      `MAKE_FAILED_TO_START`, and the VCS trigger's quiet-period type needs an import this
      file does not carry. Both values are TeamCity's own defaults, so leaving them unset
      reproduces the server exactly — confirmed afterwards: `Ship`'s dependency reads back
      `run-build-if-dependency-failed-to-start = MAKE_FAILED_TO_START` without the DSL
      mentioning it.

   Both landed in the two places the previous draft of this section named as the concentrated
   translation risk. The lesson is narrower than "be careful": **reproduce a REST value by
   omitting it when it is the default, and copy a working sibling's imports exactly rather
   than adding the one that looks right.**

   ### Reading compile errors

   **`versionedSettings/status` returns every error with file and line; the log returns the
   first and "and 4 more errors".** Use the endpoint:

   ```
   GET /app/rest/projects/id:NoSpoilers/versionedSettings/status
   ```

   It also reports progress (`Running DSL…`) and success (`Changes from VCS are applied…`),
   and it is what said the state was stuck and needed a disable/enable.

   ### Two operational notes

   - **Synchronization does not retry on its own after a failed compile.** It stops, and the
     status says so. `POST …/versionedSettings/loadSettings` restarts it. After the second
     failure it also needed a full `synchronizationMode: disabled` then `enabled` round trip,
     because TeamCity could not find a last committed revision for the project.
   - **`importFromVCS` is the only available direction here**, because `NoSpoilers_Main`
     authenticates anonymously and TeamCity therefore cannot commit generated settings back.
     "Overwrite VCS with the current settings" is not an option for this project.

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

1. ~~Decide whether macOS ships from TeamCity~~ — **decided 2026-09-09: option A**, all three
   channels from one button.
2. On `teamcity-agent-3`, in the keychain the agent's own session uses:
   - install a *Mac Installer Distribution* certificate;
   - install a *Developer ID Application* certificate;
   - `gh auth login`;
   - ~~clone `homebrew-tap` beside the build checkout~~ — **not needed since 2026-09-10**: every
     run clones it fresh. See *A fresh tap for every run*.
3. ~~Turn on **Versioned Settings** for `NoSpoilers`~~ — **done 2026-09-09**, see *Enabled
   2026-09-09* above. Original instructions kept because they are the recipe for the next
   project: turn on Versioned Settings for `NoSpoilers` — VCS root `NoSpoilers_Main`, format
   Kotlin, *Store secure values outside of VCS* on, allow UI editing off. Answer the enable
   dialog with **"overwrite VCS with the current settings"**. TeamCity compiles the DSL
   server-side and `Ship` appears; a compile error lands in `teamcity-versioned-settings.log`
   and leaves the current settings alone. Then diff: `scripts/teamcity.py settings --json`
   against the snapshot taken before, so any translation error in the DSL is a concrete
   difference rather than a surprise.
4. ~~Press it once with `ship.args = --check`~~ — **done 2026-09-09**, `Ship #2`, build id 4164.
   It stopped at the missing *Mac Installer Distribution* certificate having built and shipped
   nothing, and the press before it — `ship.args` left empty, so a real release — stopped in the
   same place for the same reason. Press it again once step 2 is done: it now reports every
   remaining gap in one run rather than the first one.
5. ~~Turn off the Xcode Cloud workflow~~ — **done 2026-09-09.** `PATCH /v1/ciWorkflows/7A43B70B…`
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
  release-and-delivery skill. The `ci_health.py` checkbox task 26 carried was dropped there
  rather than left unsatisfiable, before that task was closed and deleted.

### Option A, 2026-09-09

- **`_version.sh: version_to_ship` takes `all`.** It asks both platforms and refuses to answer
  when they disagree, printing both. That refusal lived in `ship.sh` for a day; it moved into
  the function the moment `ci-publish.sh` needed the same answer, because two copies of "which
  version ships" is how they come to disagree — the defect this function was written to fix.
- **`ship.sh` forwards anything after the version to both `release.sh` invocations**, the same
  `"$@"` passthrough `ship-ios.sh` and `ship-appstore.sh` already used. That is how the agent's
  credentials reach the engine without `ship.sh` learning what a build agent is. With a version
  passed it never prompts, so it was already usable as a CI step.
- **`ci-publish.sh --platform all`** — hands over to `ship.sh` instead of a per-platform
  wrapper, and asserts what the extra channel needs before anything is built:
  - the *Developer ID Application* identity, by **signing a probe binary**, not by presence:
    a locked keychain lists an identity happily and then refuses it, and this one is used
    after the App Store upload has already happened;
  - **`notarytool history`** with the App Manager key — a read that authenticates, lists this
    team's submissions and changes nothing, so the credentials that will notarize are the
    credentials that were tested;
  - `gh auth status`, because the SSH key checked for git does not authenticate the API;
  - a fresh clone of `homebrew-tap`, and `git push --dry-run` on it — a sibling checkout until
    2026-09-10.
- **Notarization is given a key, not the `no-spoilers-notarytool` keychain profile.** A profile
  is created interactively by `notarytool store-credentials` and lives in the login keychain,
  so it is one more thing that is present and unusable when that keychain is locked — the
  failure this whole file exists to catch. `release.sh` already took `--notarytool-key`.
- **A missing certificate now prints what the agent does hold.** The identity strings are
  conventions written by hand and the first press is the first comparison with a real keychain.
- **The approval tag is written per platform.** `all` reaches that branch only when both trains
  said closed, so both `ios/vX.Y.Z` and `macos/vX.Y.Z` are owed and writing one would leave the
  record half true.
- Docs: `docs/guides/building.md` — *TestFlight from TeamCity* is now *Shipping from TeamCity*
  and describes the one button; `README.md` cross-reference followed.
- **`.teamcity/settings.kts` and `.teamcity/pom.xml`** — the whole project as code, read back
  from the server rather than inferred; see *The plan* step 4 for what was read and how the
  file was checked against it. The `pom.xml` is FunMax's with the three per-project names
  changed, per `TEAMCITY-AGENTS.md` §8.
### Every gap in one press, 2026-09-09

`refuse` beside `fail`: under `--check` it records the message and lets the run carry on, and on a
real press it is `fail` unchanged. So a real press still stops at the first gap — everything after
it would describe a machine that cannot ship anyway — and `--check` walks all nine assertions and
prints what is missing as one numbered list.

- The checks that depend on an earlier one are guarded rather than left to fail again, so one gap
  is one message: no `codesign` probe against a certificate that is not there, no `notarytool
  history` without a key to run it with, no `gh auth status` without `gh`, no `git push --dry-run`
  into a tap that was never cloned.
- `security find-identity` prints once per run, not once per missing certificate.
- The report comes **before** the version question, which asks App Store Connect using a key that
  may be one of the things found missing.
- `clang could not build the signing probe` stays a hard `fail` in both modes. An agent whose
  compiler is broken has no certificate problem worth listing.

- **`scripts/teamcity.py settings`** — added to the `teamcity` plugin in
  `npomfret/agent-standards`, because the CLI could say how a configuration ran and not what it
  was. Prints steps, triggers, locks, agent requirements and dependency flags, plus the
  project's features and VCS roots; `--json` for a before-and-after diff. Same GET path as
  every other query, so the token still arrives on stdin; the selftest that asserts that still
  passes. Committed there as `80bc31c`; the conversion lessons above are in that plugin's
  `teamcity-builds` skill as `21f6f1d`, so the next project does not repay them.

### The tap is pulled before it is pushed, 2026-09-10

Found while working out where the agent's `homebrew-tap` clone should go. `release.sh` edited
the cask, committed and pushed it **without pulling first**, and `ci-publish.sh`'s
`git push --dry-run` passes on a checkout that is merely behind. The tap holds more than this
cask and both the laptop and the agent publish to it, so any clone falls behind the moment the
other one pushes — and the push that then fails comes after the GitHub release is public.

`bring_tap_current` in `release.sh`: refuses uncommitted changes to tracked files (untracked
ones such as the laptop tap's `.DS_Store` are left alone), then `git pull --rebase`, aborting a
conflicting rebase so the tap is left as it was. Called in preflight and again immediately
before the cask is edited. A failure at that second call prints the `version` and `sha256` the
cask needs, since the release is already public by then. `docs/guides/building.md` says the same.

### A fresh tap for every run, 2026-09-10

The fix above made a stale tap safe; it did not make a hand-made one right. A clone left under
`teamcity-agent-3/work/` belongs to one agent, is TeamCity's to clean, and would have to be
repeated on every agent that can take `Ship`. So `ci-publish.sh` now clones
`git@github.com:npomfret/homebrew-tap.git` into a fresh directory under `TMPDIR` — which `Ship`
points at the build's own temp directory, cleared by TeamCity before the next build — asserts the
cask is there and that `push --dry-run` succeeds, and hands the path to `release.sh` as
`--homebrew-tap`. `ship.sh` already forwards everything after the version to both of its
`release.sh` invocations, so nothing between them changed. `release.sh` run without the option,
which is every laptop run, keeps using `../homebrew-tap`.

The clone is skipped when the GitHub SSH check failed, so one gap is still one message. Which agent
takes the build no longer matters to the tap, and the certificates live in the `nickpomfret` user's
keychain rather than in any agent's directory.

## Verification

- [x] `scripts/verify-python-selftests.sh` — five scripts green, 2026-09-09 (189 cases; was six
      scripts and 206 before `ci_health.py` went)
- [x] `scripts/verify-core-tests.sh`, `verify-ios-build.sh`, `verify-mac-build.sh`,
      `verify-widget-build.sh` all green, 2026-09-09
- [x] No reference anywhere to a deleted file: `ci_health`, `ci_pre_xcodebuild`, `ci-publish-ios`,
      `ci_scripts`, `find_ci_product`, `source_commit` — every remaining hit is prose naming them
      as removed
- [x] `ci-publish.sh` refuses a missing `--platform` and an unknown one, exit 1 both, and both
      messages name `all` — 2026-09-09
- [x] `version_to_ship all` returns `1.1.4` against the live record, and returns nothing with
      exit 1 and both versions named when the platforms disagree — proved with a stubbed
      `appstore_status.py` reporting the macOS train closed and the iOS one open, 2026-09-09
- [x] `version_to_ship` leaves the caller's `errexit` off, before and after, `all` included
- [x] **`ship.sh` gives both `release.sh` invocations one build number and every credential**,
      proved with a stub `release.sh` that prints its arguments: `9.9.9 … --build 10025` with
      the signing *and* notarization flags on the macOS `--channel both` run and the iOS
      `--channel app-store` run alike. The no-argument path still offers `1.1.4` and prompts.
- [x] `bash -n` on `_version.sh`, `ship.sh`, `ci-publish.sh`; `verify-python-selftests.sh`
      five scripts green (196 cases), 2026-09-09
- [x] The first assertion fires in the sandbox and the new diagnostic earns its place: it
      reports `0 valid identities found`, which distinguishes a wrong identity string from a
      keychain the session cannot reach
- [x] **`ci-publish.sh --check` has run on the agent** — `Ship #2`, build id 4164, 2026-09-09.
      Assertions 1 and 2 executed; it stopped at 2.
- [x] **The login keychain is unlocked in the agent's own session**, proved by the probe binary
      being signed rather than by `find-identity` listing anything. This is the question the
      `--check` mode was written for and it now has an answer.
- [x] **Every assertion has now run on the agent** — `Ship #3`, build id 4178, `ced967a`,
      2026-09-09. Three failed, and they are the three items above. Everything else passed,
      including `notarytool history` and `gh auth status`, neither of which had ever been executed
      against this agent's credentials.
- [ ] **The Developer ID *probe* is still unrun**, as opposed to the presence check that refused
      it: no certificate means nothing to sign the probe binary with. It will run on the first
      press after the certificate is installed.
- [x] **`--check` reports every gap**, exercised against a throwaway checkout with an empty `HOME`:
      nine gaps in one run, the identity list printed once, and `notarytool` not called at all
      when its key is absent. The same run without `--check` stops at the first gap, unchanged.
      `--platform ios --check` reports four, correctly omitting the installer, Developer ID,
      notarization, `gh` and tap assertions. `bash -n` clean.
- [x] **The tap is brought current, and refuses what it should**, 2026-09-10 — `release.sh` run
      against throwaway remotes, five cases: a tap behind its upstream is pulled; an uncommitted
      cask edit is refused and left untouched; an untracked `.DS_Store` is ignored while the tap
      is still pulled; an unpushed cask commit is carried onto a remote that advanced elsewhere;
      a conflicting unpushed commit is refused with no rebase left in progress and the tap on its
      own commit. The second call, at the tail, is the same function and has not run end to end.
      `bash -n` clean.
- [x] **Every run clones its own tap**, 2026-09-10 — `ci-publish.sh --platform all --check` against
      local fake remotes with a stub `ssh`: a remote with the cask gives no tap gap and leaves the
      clone inside the `TMPDIR` the run was given; a remote without the cask and an unreachable one
      each give one gap; a failed GitHub SSH check gives its own gap and no clone attempt.
      `ship.sh`, with `release.sh` stubbed, hands `--homebrew-tap` — a path containing a space — to
      both invocations. `release.sh` uses the path it is given, names the option when no tap is
      found, and accepts it on an iOS run.
- [x] **macOS `mktemp -d` ignores `TMPDIR` without a template**, found by that test: the first
      clones landed under `/var/folders/…/T`, where TeamCity would never clear them. Both of
      `ci-publish.sh`'s temp folders now name `${TMPDIR}` explicitly; on the re-run no new folder
      appeared under `/var/folders`. `bash -n` clean on both scripts.
- [ ] **The clone has not run on the agent.** It needs the agent's own SSH key against the real
      `homebrew-tap`; the next `Ship --check` press exercises it.
- [ ] **The notarization credential is unverified even in principle from here.** The `.p8` keys
      are outside what this session may read, so `notarytool history` has not been run with
      `ASC6H3SL2D` anywhere. If the App Manager key turns out not to carry notary access, the
      key id in `ci-publish.sh` is the one line to change.
- [x] `gh auth status` and `git -C ../homebrew-tap push --dry-run` both pass **on the laptop**,
      which proves the assertion logic and says nothing about the agent
- [ ] **Nothing has shipped through the new path.** `Ship` has now run three times — #1 (4147)
      and #2 (4164) at `9ffba57`, #3 (4178) at `ced967a` — all three stopped by their own
      preflight. No archive has ever been made under a publishing configuration.

### The first two presses, 2026-09-09

Both red, both in under two seconds, and between them they answered more than a green run would
have.

**`Ship #1`, build id 4147, was pressed with `ship.args` empty** — `ci-publish.sh --platform all`
with no `--check`, which is a real release of all three channels. It stopped at assertion 2 with
nothing archived, nothing uploaded, nothing committed and nothing tagged. The preflight paid for
itself on the first press of the button it guards, which is the argument this file makes about
itself, now with evidence.

**`Ship #2`, build id 4164, was the `--check` press**, and stopped in the same place.

**`Ship #3`, build id 4178, at `ced967a`, was the first press that described the whole agent** —
three seconds, three gaps, and the two credentials this task had never been able to test from
anywhere both passed on the way past. See *What the agent still needs* below.

**What assertion 1 proved.** It did not merely list the certificate, it signed the probe binary
with it. The login keychain is unlocked for the agent's own session — the question the whole
`--check` mode exists for, and the one the task said had no answer from an SSH shell or a sandbox.

**What the agent holds**, printed by the failure itself:

```
1) Apple Development: Nick Pomfret (V4937W3NU8)
2) Apple Distribution: Nick Pomfret (6FZN56WC8G)
   2 valid identities found
```

Two identities, and the team id `6FZN56WC8G` in the missing installer string matches the
certificate that is there. So the three identity strings written by hand are right, and the two
missing certificates are missing rather than misspelled.

**What it cost: one press per gap.** This task claimed `--check` would name every gap in one run
because a failure prints the identity list. It does not — every assertion was a `fail`, which
exits. Fixed the same day; see *Every gap in one press* below.

### What the agent still needs, measured 2026-09-09

`Ship #3` walked all nine assertions. What passed is as much of the result as what failed, because
four of the passes had never been executed anywhere:

- **`notarytool history` authenticated** with `AuthKey_ASC6H3SL2D.p8`. The App Manager key does
  carry notary access, so the key id in `ci-publish.sh` needed no change — the one line this task
  said might have to.
- **`gh` is installed and logged in**, and the SSH push remote authenticates to GitHub.
- Both App Store Connect keys are on disk, and `git user.name` / `user.email` are set.

Two things remain, both on the machine:

1. A *Mac Installer Distribution* certificate in the agent's login keychain.
2. A *Developer ID Application* certificate in the same keychain.

The third gap `Ship #3` reported — no `homebrew-tap` beside the checkout — is gone rather than
fixed: every run now clones the tap for itself. See *A fresh tap for every run*.

## Residual risk

The macOS half is unproven in a way the iOS half is not: `ci-publish-ios.sh` shipped iOS 1.1.2
build 10008 on 2026-08-25, and no macOS archive has ever been made on the agent. All three
identity strings in the script are conventional and have not been read off the certificates this
repository will actually use — `--check` prints the real list on failure, so this costs one press
rather than a guessing loop.

**The Homebrew channel is the risk option A adds, and it is asymmetric.** `--channel both`
uploads to the App Store before it exports for Developer ID, so a failure in the new half leaves
a build already with Apple. That ordering is deliberate and documented, and the preflight is
built around it — every Homebrew prerequisite is asserted at the head of the run precisely
because it is used at the tail — but an assertion is not a proof, and none of them have executed
on the agent.

**`release.sh`'s own bare prompt still offers `suggest_next_version`.** It is the last instance of
the defect fixed on 2026-09-09 in `ship.sh` and `ci-publish.sh`. It cannot bite either of them —
both always pass a version — so it only reaches a person running `release.sh` directly. Fixing it
means reading `--platform` before the version, which reorders that script's argument handling, so
it is recorded here rather than done in passing.

**Correction, 2026-09-09.** This task previously called `build/10023` "a `release.sh` run on the
laptop". Its tagger is `nick pomfret`; `build/10024`, written by this laptop on 2026-09-09, is
tagged `npomfret`. So 10023 was written under a different git identity and the machine that made
it is not established. What the claim was supporting still holds by the stronger evidence: TeamCity
has never run a build under a publishing configuration, so wherever 10023 came from, it did not
come from the path this task is building.

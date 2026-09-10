# Task 38: TestFlight delivery follows Funmax

**Status: IN PROGRESS. Raised 2026-09-10.**
- **On `main` (`101e61c` to `bc0c742`):** the Apple engine, the Homebrew separation, the new `Ship`
  step, and the fixes from a review of them.
- **Proven on TeamCity:** `Ship #6` passed an iOS `--check` on `macstudio-3` and planned build 10025.
- **Not yet done:** nothing has archived, uploaded or delivered through the new path.
- **Next:** the first real iOS delivery, which waits on the owner's approval.
- **Blocked:** macOS, on the Mac Installer Distribution identity.

See *Progress*, *Learned while driving TeamCity* and *Next, in order*.

Make No Spoilers use the proven Super Funmax Music deployment pattern on the shared
TeamCity agents: verify a commit, archive that exact commit, upload it, wait for Apple
processing, write its tester notes, and confirm it is available to internal TestFlight
testers. The same entry point should be usable by a person or an agent.

**This supersedes task 36's release design.** Its decisions that a release is a manual
button covering all three channels, that every channel must share a version/build
number, and that `release.sh` must remain unchanged no longer apply. Its completed
TeamCity migration and historical evidence remain useful. The remaining work is not
only installing credentials: the release orchestration also needs changing.

**Confirmed scope**

- Funmax is the working reference. Change No Spoilers to achieve consistency; do not
  redesign Funmax as part of this task.
- Automation ends with an installable internal TestFlight build and correct notes,
  for both iOS and macOS. Final App Review submission remains a manual button press.
- Homebrew is a completely separate flow: its own trigger, credentials, prerequisites
  and release cadence. Neither flow waits for the other. Version/build numbers need
  not remain synchronised between Homebrew and Apple.
- Shared helpers are fine; a combined Apple/Homebrew release orchestrator is unnecessary.
- Use the existing three agents on this Mac, all running as `nickpomfret`, and the
  existing Apple team. No additional agent or separate Apple account is needed.

**Evidence from the investigation**

Source snapshots: No Spoilers `be9b9873`, Funmax `a9c82aa9`, shared TeamCity docs
`e845bec0`. Live reads were made on 2026-09-10. Recheck machine state and live
configuration when implementing; certificate observations are dated evidence.

**Update before commit:** No Spoilers was fast-forwarded to `95fdae2`. Commit
`0c0db91` already replaces the hand-made sibling tap with a fresh temporary clone;
`9edcccd` refreshes the tap before cask updates. That checkout defect is fixed in
current source. The historical preflight failures below remain evidence of what
happened, while Homebrew's coupling to Apple delivery remains an open problem.

| Evidence | Finding |
|---|---|
| [Funmax Ship #61](https://ci.snowmonkey.co.uk/buildConfiguration/SuperFunMaxMusic_Ship/3130) | `macstudio-2` delivered 1.3 (138) from verified commit `83b10631f9a8` on 2026-09-05. Archive, upload, processing wait, tester note and Kitchen access completed in about five minutes. Seven recent Ship runs inspected were successful. |
| [No Spoilers Ship #4](https://ci.snowmonkey.co.uk/buildConfiguration/NoSpoilers_Ship/4202) | On 2026-09-09, `macstudio-3` ran `--platform all --check`. Apple Distribution signing passed. Mac Installer Distribution, Developer ID Application and the sibling Homebrew tap checkout were missing. All four runs of the new Ship configuration stopped before archiving. |
| [No Spoilers TestFlight #3](https://ci.snowmonkey.co.uk/buildConfiguration/NoSpoilers_TestFlight/4148) | The separate distribution job succeeded on both platforms and found build 10024 already assigned to Internal. It builds and uploads nothing. |
| Live App Store Connect | No Spoilers macOS 1.1.3/build 104 and iOS 1.1.3/build 112 are `READY_FOR_SALE`. Build 10024 is the newest uploaded and installable internal TestFlight build on both platforms. Those uploads did not come from the new Ship job. |
| Local provisioning profiles | Distribution profiles exist for Funmax and for No Spoilers' iOS app and widget. They expire on 2027-08-21, permit distribution and include the distribution certificate reported by the successful agent probe. Both No Spoilers profiles permit `group.pomocorp.no-spoilers`. |

Funmax's latest verification was red at investigation time because its shared TeamCity
CLI selftest could not find the installed plugin. Its gate correctly withheld another
Ship. That operational issue does not invalidate the successful delivery pattern and
is not a reason to redesign its release scripts.

**Current problems: symptoms, causes and impact**

These describe the inspected revision and dated live evidence above. They distinguish
what has actually failed from what the code would allow once preflight is repaired.

| Problem | Evidence and cause | Impact |
|---|---|---|
| The new Ship job has never archived successfully | Runs #1–#4 failed before archive. Latest #4, build ID 4202, ran `scripts/ci-publish.sh --platform all --check` at `ced967a9` on `macstudio-3`. | There is no demonstrated end-to-end delivery through the new configuration. Existing build 10024 must not be counted as proof of this path. |
| macOS installer signing is unavailable in the last agent preflight | Missing `3rd Party Mac Developer Installer: Nick Pomfret (6FZN56WC8G)`. Apple Distribution's binary signing probe passed. | Mac App Store package export is blocked; the working iOS distribution identity alone does not satisfy the package-signing check. |
| Homebrew prerequisites block even an Apple release | The same preflight also reported missing `Developer ID Application: Nick Pomfret (6FZN56WC8G)` and `/Users/nickpomfret/teamcity-agent-3/work/homebrew-tap/Casks/no-spoilers.rb`. | The combined job refuses before either Apple upload, despite these two prerequisites belonging to the independent Homebrew flow. |
| A later Homebrew failure can prevent iOS delivery | `ship.sh` invokes macOS `--channel both` before iOS, under `set -e`. That macOS invocation uploads to Apple, then notarizes/publishes Homebrew. | A Homebrew failure after the Mac upload stops the shell before the iOS invocation. This is a code-path finding, not a stage reached by the failed new Ship runs. |
| A green upload does not mean the job delivered to testers | `release.sh` finishes upload by printing a command to run later. TeamCity TestFlight has no dependency on Ship and no automatic trigger. | Someone must wait for processing and press another button. Current testers do have 10024, but the proposed unattended outcome is absent. |
| Tested code can differ from archived code | In the inspected `release.sh`, the test gate is at line 362, version mutation/commit follows around line 429, and a rejected push can cause `git pull --rebase` at line 467 before archive. | A concurrent commit can enter the archive without passing this run's verification. Even a version-only commit makes TeamCity's recorded revision differ from the archive. This is a correctness defect found in code, not an observed bad upload from the new job. |
| Queued releases can be refused because main advanced | `release.sh` requires the checkout's upstream to be an ancestor of HEAD. TeamCity fixes a revision when queuing, so a correctly verified older revision can fail this check when it finally starts. | Unrelated work landing on main can stop a release. The new flow needs an explicit stale-revision policy, not branch mutation to make the push succeed. |
| The default version decision can block when Apple platforms disagree | `_version.sh:version_to_ship all` refuses if macOS and iOS resolve to different versions, for example when only one platform's current version is approved. | The shared app record does not imply simultaneous approval. Apple-only orchestration must handle these states without coupling them to Homebrew. No disagreement was established in the current live records. |
| Normal status output can hide delivery failures | `.teamcity/cli.json` whitelists only VerifyPython, VerifyXcode, VerifySwiftTests and Verify. | A verification status read can omit every failed Ship run. Read Ship explicitly until the reporting scope is changed. |
| A green verification chain does not prove a distributable Release package | The app compile wrappers select Debug/default Debug and disable signing. There is no Release export or installation check in those legs. | Release-only compilation, profile/entitlement and installer-signing failures surface during shipping. Unsigned verification remains useful, but does not establish signing readiness. |

The latest failed preflight also established useful **passes**: both API-key files
were present, Apple Distribution could sign, notarization API authentication worked,
GitHub SSH authentication worked, `gh` was logged in, and git author settings existed.
Do not restart diagnosis by assuming all credentials are absent. The Homebrew passes
remain irrelevant to whether an Apple-only job is ready.

Two additional implementation risks have not caused the observed Ship failures:
single-page ASC reads can omit builds after the first 200, and the current export
plist does not explicitly disable Xcode build-number management. Address both before
enabling automatic uploads, while keeping them distinct from the proven preflight
blockers. Cross-project Xcode locking is likewise a concurrency concern to validate,
not a diagnosed cause of these four failed runs.

**The reference flow**

Read Funmax's files before implementing:

- [TeamCity settings](../../super-funmax-music/.teamcity/settings.kts)
- [submit_build.py](../../super-funmax-music/apple/scripts/submit_build.py)
- [testflight_distribute.py](../../super-funmax-music/apple/scripts/testflight_distribute.py)
- [Builds and delivery](../../super-funmax-music/apple/docs/builds-and-delivery.md)

Relevant pushes run Compile, Checks, Unit and three UI legs, collected by a true
composite Verdict. Ship follows successful Verdict completion and has a snapshot
dependency on the same revision. A nightly also runs the chain and ships when green.

Ship calls `submit_build.py --apply --tested`. It refuses a dirty checkout, reads
Release build settings, allocates an unused build number from App Store Connect,
archives with `CURRENT_PROJECT_VERSION=N`, uploads through `xcodebuild -exportArchive`,
waits for processing and invokes the distributor with the archived commit for notes.
It never changes the branch or commits a version bump. A local invocation without
`--tested` runs its own unit-test gate.

Its export options are explicit: `method=app-store-connect`, `destination=upload`,
`signingStyle=automatic`, `uploadSymbols=true`, `manageAppVersionAndBuildNumber=false`.
Apple tools run with `/usr/bin` first on PATH. Python and Apple's CLI tools already
implement this; introducing fastlane or translating it to TypeScript would add work
without improving consistency.

**Differences and pitfalls to address**

1. **Homebrew blocks Apple today.** `ci-publish.sh --platform all` checks Developer ID,
   notarization, GitHub release access and a tap checkout before any Apple upload.
   `ship.sh` then runs Mac App Store, Homebrew and finally iOS. A Homebrew failure can
   strand a partial Apple release. Remove those prerequisites and that dependency.
2. **The tested revision can move.** `release.sh` runs the core-test gate, then may
   commit a marketing-version change and `git pull --rebase` before archiving.
   The resulting source may differ from both the local gate and the TeamCity-tested
   revision. Commit version changes before verification; refuse source movement in Ship.
3. **Upload is currently the finish line.** The release script prints instructions
   for a later manual distribution command. Integrate bounded processing waits,
   notes and confirmed group membership into the Apple job's success criteria.
4. **Only one of the three observed preflight blockers belongs to Apple delivery.**
   The Mac Installer Distribution identity, including its private key, is needed for
   the macOS package. Developer ID and the tap belong exclusively to Homebrew. No
   matching macOS distribution profile was found locally; archive/export must establish
   whether automatic provisioning can provide it or local provisioning is needed.
5. **Keychain access is session-dependent.** The agent signed a probe successfully
   while the sandboxed audit shell reported zero usable identities. Neither that
   sandbox result nor an SSH identity listing proves whether an agent can sign.
   Probe in a build session and prove the installer identity with an exported package.
6. **Verification is weaker than the reference.** Current app checks are unsigned
   Debug builds; Verify is an ordinary empty build configuration, not a composite.
   Add Release compile coverage and proper test reporting. Keep the unsigned checks'
   temporary HOME isolated from the signing environment.
7. **Export options should match explicitly.** The current plist uses deprecated
   `app-store` and omits `manageAppVersionAndBuildNumber`. Local Xcode help confirms
   the modern method and the default YES for number management. This was not the
   observed preflight failure, but must be corrected when adopting direct upload.
8. **Do not blindly copy newest-build selection.** Funmax waits for an exact build
   but its distributor then selects the newest. No Spoilers already supports
   `--platform` and `--build N`; carry the exact uploaded identity through delivery.
9. **Pagination and retries become important with automatic uploads.** No Spoilers'
   build readers take one page of 200. Traverse all relevant pages and count expired
   builds when allocating numbers. A timeout must leave a resumable record, not cause
   another upload of an already accepted build.
10. **Project-local locks do not coordinate the Mac.** `funmax-xcode` and
    `no-spoilers-xcode` are different resources. Funmax Ship refuses other running
    xcodebuild processes. Use an intentionally shared resource where exclusion is
    necessary, or prove the intended concurrency with isolated build directories.
    Any shared-infrastructure change must be coordinated rather than silently changing
    Funmax's configuration.

The logged-in Apple account is not the whole signing credential. Reuse the installed
distribution identity, matching profiles and existing `.p8` files. Use Funmax's
`ASC_ISSUER_ID`, `ASC_KEY_ID` and `ASC_ADMIN_KEY_ID` conventions. The latter names an
App Manager key, not necessarily an Admin-role key; do not escalate roles to work
around a missing local profile without inspecting the actual export error.

**Decisions, 2026-09-10**

- **The Apple engine is Python and Funmax-shaped**: a new `scripts/submit_build.py`, used by
  a person and by `Ship` alike, reusing `appstore_status`, `asc_write` and
  `testflight_distribute`. `release.sh` keeps the Developer ID / Homebrew channel only;
  `ship.sh`, `ship-ios.sh` and `ship-appstore.sh` are retired rather than kept beside it.
- **The Mac Installer Distribution identity is exported from the laptop** that shipped macOS
  1.1.4 build 10024, not created anew, so no certificate slot is spent.
- **A closed train is refused, never opened by `Ship`.** The refusal names the command that
  commits `open vX.Y.Z`; that commit is verified and shipped like any other.
- **The nightly ships when green**, matching Funmax.

**Read-back, 2026-09-10** (this machine is `macstudio.local`, which runs all three agents)

- Live TeamCity settings equal `.teamcity/settings.kts`; `Verify #100` green at `0c0db91`.
- `macstudio-3`'s own `teamcity-build.log` holds Ship #4 (id 4202): the installer identity,
  the Developer ID identity and the old sibling tap path were missing; two identities listed.
- The `nickpomfret` keychain holds **no** installer or Developer ID certificate at all.
  `Apple Distribution` is SHA-1 `6E62FC93…`, embedded in both No Spoilers iOS store profiles.
- Every provisioning profile on this machine is iOS; **there is no macOS App Store profile**.
- `build/10024` was tagged by `npomfret`; this machine's git user is `nick pomfret`, so the
  1.1.4 three-channel ship came from the laptop.
- `scripts/teamcity.py` did not resolve the plugin here (the cause of Funmax's red
  selftest); `TEAMCITY_CLI=~/projects/agent-standards/plugins/teamcity/scripts/teamcity.py`
  worked. *Superseded later that day: see "How the shared CLI resolves here" under Progress.*
- An agent session's sandbox cannot run `xcodebuild`, so signing is proved by builds.

**Implementation plan**

- [x] Read back current TeamCity settings, parameters, agent compatibility and latest
  release logs. Preserve existing configuration identities/history when editing the DSL.
- [x] Build an Apple-only entry point following Funmax's archive/upload/wait/distribute
  sequence. Adapt or replace the new No Spoilers orchestration; reuse its working ASC
  helpers instead of creating duplicate authentication or distribution implementations.
- [x] Remove Homebrew from the Apple call graph and preflight. Keep its direct-download
  entry point independent. Do not make this task depend on completing Homebrew CI.
- [x] Move marketing-version changes before verification. During Ship require a clean,
  fixed revision, including when a queued build becomes older than main. Either ship
  that verified revision faithfully or explicitly refuse/requeue; never rebase it.
- [x] Define build allocation and provenance. Preserve existing tags/history and never
  reset the ledger. A coordinated iOS/macOS run may allocate one Apple number, but
  record each platform separately. Existing `build/N` tags can include Homebrew history;
  resolve that namespace explicitly so separating flows introduces neither collisions
  nor an ongoing requirement to release both channels together.
- [x] Record commit, marketing version, build number, platform, ASC build ID and stage
  results in a durable TeamCity release artifact. Support resuming upload/processing/
  distribution as appropriate, including a partial two-platform success.
- [x] Use the explicit Funmax export options, bounded waits and clear progress messages.
  Verify archive and exported/uploaded versions, including the iOS extension.
- [x] Pass the exact build to notes/distribution and read back Internal membership.
  Keep explicit-build manual distribution as a recovery command. Do not add automatic
  final App Review submission or external-group distribution.
- [ ] Provision the missing Mac Installer identity for `nickpomfret`; establish any
  macOS profile requirements. Prove signing/export in each eligible agent session.
- [ ] Convert Verify to a composite, add Release compilation, publish test results,
  and make successful verification trigger Apple Ship with matching revisions.
- [x] Include automated delivery in ordinary CLI status reporting; the current
  `.teamcity/cli.json` whitelist hides Ship/TestFlight. Ensure the shared CLI resolves
  on this machine without making unrelated release-script selftests depend on it.
  Done 2026-09-10:
  - `cli.json` lists both, and `status` reports them;
  - the CLI resolves from the `npomfret` marketplace clone with no `TEAMCITY_CLI`;
  - none of the six selftest suites calls it.
- [x] Set the nightly policy explicitly. Recommended default is to match Funmax's
  existing successful-verification trigger, including green nightlies. Suppressing
  delivery of unchanged commits is a separate refinement, not an accidental difference.
- [ ] Validate the new path with a first real delivery, then enable unattended triggering.
  Preserve listing/screenshot tools and manual promotion of an already uploaded build.
- [x] Update task 36 and `docs/guides/building.md` to point to the implemented flow;
  remove contradictory instructions. Add any further reusable lessons to agent-standards.

**Progress, 2026-09-10**

- `101e61c`: `appstore_status.all_pages` follows every `links.next` and refuses a runaway or
  off-API cursor; `testflight_distribute` settles Apple's own-add 422 and `--apply` reads back group
  membership and the note, exiting 1 otherwise. Live record then: iOS 105 builds and macOS 85, one
  page each, so paging was preventive. Dry runs against build 10024 read correctly on both platforms.
- `03adbbe`: `scripts/submit_build.py`, the Apple engine. Dry run on a clean tree: 1.1.4, build 10025,
  both trains open. `Verify #102` green at `03adbbe`.
- `6e0c2df`: `scripts/open-version.sh`; `ci-publish.sh` split into Apple and
  `--platform homebrew`; `release.sh` reduced to Developer ID, releasing the committed version and
  reserving `build/N` before archiving; `ship.sh`, `ship-ios.sh`, `ship-appstore.sh`,
  `ExportOptions-AppStore.plist` and `version_to_ship` removed; `Ship` running `ci-publish.sh
  --platform %ship.platform% --tested %ship.args%` with record artifacts, still untriggered;
  `.teamcity/cli.json` covering `Ship` and `TestFlight`; building guide, README, important-code,
  Codex rules and task 36 updated.
- Evidence for that set, gathered in throwaway repositories: `open-version.sh` refused a missing or
  malformed version, the same, a lower and a tagged version, a dirty tree and a checkout behind origin,
  and on success set 1.1.5 in all six configurations and pushed only to the throwaway origin;
  `ci-publish.sh --platform all --check` reported the installer identity as its only gap and
  `--platform homebrew --check` the Developer ID identity as its only one; `release.sh` refused a
  version other than the commit's and a missing tap. All six Python selftest suites green.
- **Blocked on the owner**: the laptop export was `Apple Distribution` and `Apple Development`, not the
  installer identity. Nothing was imported.
- `scripts/teamcity.py`'s ssh was refused by this session's sandbox. Why, and the fix, are under
  "How the shared CLI resolves here" below. The TeamCity token is deliberately not read outside the
  shared CLI.
- **`Ship` still carries no `uuid` in the DSL**, as before. Its real uuid could not be read (the
  sandbox refusal above), and the five `settings.kts` commits all predate Ship's first run, so Ship
  was created by the DSL and its id has not changed since. Confirmed after the sync: Ship's history
  (#1–#4) survived.
- `.teamcity/cli.json` now reports `Ship` and `TestFlight` (`status` showed both after the change).
- **How the shared CLI resolves here.** The watchers for the `6e0c2df` sync and its `Verify` ended
  without an answer: the sandbox refused ssh on every poll. The cause was two things together:
  - the `teamcity@npomfret` plugin was enabled in `.claude/settings.json` but its marketplace was never
    added, so `scripts/teamcity.py` found the CLI only through `TEAMCITY_CLI`;
  - a `TEAMCITY_CLI=…` prefix stops the command matching the sandbox exclusion
    `python3 scripts/teamcity.py *`, so ssh stayed sandboxed.

  Once the owner ran `claude plugin marketplace add npomfret/agent-standards`, plain
  `python3 scripts/teamcity.py status` found the CLI in the marketplace clone and reached the server.
- **Observed 2026-09-10, once TeamCity could be read:**
  - `Verify #103` green at `6e0c2df`, and `Verify #104` green at `cd64e4b`, all three legs.
  - `97f96d5` touched only `.claude/` and `.mcp.json`, outside `Verify`'s trigger rules, so it
    correctly has no build.
  - `Ship`'s live settings match `cd64e4b`: the `ci-publish.sh --platform %ship.platform% --tested
    %ship.args%` step, a 360-minute timeout, both artifact rules, the write lock, the snapshot
    dependency on `Verify` taking successful builds only, and no trigger.
  - `Ship #4` (on `ced967a`, before this task) is still listed, so its history survived the DSL.
- **`Ship #5`, 2026-09-10 10:40, `macstudio-3`, `e679e45`, owner-pressed with `ship.args = --check`.**
  It ran `scripts/ci-publish.sh --platform all --tested --check` after `Verify #105` went green on the
  same revision.
  - In that agent session, three checks passed: `Apple Distribution` really signs, both App Store
    Connect keys are present, and the checkout can push a tag.
  - The one gap reported was the missing `3rd Party Mac Developer Installer` identity. The agent sees
    only `Apple Development` and `Apple Distribution`.
  - Because there was a gap, `submit_build.py`'s dry run did not start. Nothing was built or
    reserved, and there is no record artifact.
  - `macstudio-1` and `-2` remain unproven.
- **`Ship #6`, 2026-09-10 10:43, `macstudio-3`, `64c98e9`, `ship.platform = ios`, `--check`.** Green,
  after `Verify #106`.
  - All three checks passed, and the installer was correctly not checked.
  - The dry run read App Store Connect: `1.1.4 from 64c98e9d191d`, and it would reserve build 10025.
  - Nothing was reserved. `appstore_status.py --next-build` also said 10025 from this machine, and
    origin's newest tag was still `build/10024`.
  - **It exposed a fault in `--check`.** The plan said it "would run scripts/verify-core-tests.sh",
    which the real run skips. `ci-publish.sh` passed the forwarded arguments, `--tested` included,
    to the real run but not to the dry run. A real run would not have been affected; only the
    check's description of it was wrong.
- **A review of `86b6277..37e0ef0` raised four findings; all four were confirmed in the code and
  fixed:**
  1. **An App Store Connect error after an upload ended the whole run.** macOS never ran, and the
     record said only `uploaded`. Now a 429, 5xx or dropped connection during the wait is another
     poll (`transient`). `ship_platform` records any other failure against the stage it happened in,
     with the recovery that applies, and returns so the next platform runs.
     `appstore_status.Refused` carries the HTTP status and is still a `SystemExit` with the same
     message.
  2. **One identity reserving one number twice in one second wrote identical tag objects, and both
     pushes succeeded.** `claim` adds a `Reservation: <uuid> on <host>` line and reads origin back,
     rather than trusting the push's exit status. `release.sh` now reserves the same way.
  3. **The read-back and `repair_note` compared the build number only.** A note naming the right
     build from the wrong commit passed. Both now require the exact `Build N from <sha12>` line for
     the commit `ship_commit` resolves (`note_names_commit`). The number alone is checked only for
     builds nothing records.
  4. **`Ship`'s 180-minute timeout was under the script's own worst case of 280 minutes.**
     `Ship` now allows 360 minutes. The script's `worst_case` is 330, plus a 15-minute margin for
     the record. The selftest checks that total against `settings.kts`, and delivery now has a
     ten-minute limit.
  - **Evidence:**
    - The selftests are green: 256 cases (`testflight_distribute` 59, `submit_build` 44).
    - `bash -n` and `git diff --check` are clean.
    - Putting each old behaviour back, in memory, fails its case:
      - a fixed reservation id reproduces the race, two failures;
      - the old 180-minute `settings.kts` fails the timeout check;
      - number-only note checks give three failures;
      - no retry fails the wait case.
- **What the review leaves open:**
  - **Homebrew still needs App Store Connect to choose its build number.** `next_build_number`
    reads both platforms, so a Developer ID release cannot start while that API is unreachable. This
    comes from the shared number ledger, a design choice. It is recorded here, not changed.
  - **A lesson for agent-standards:** Funmax's `Ship` has the same timeout gap, 90 minutes around
    the same 40/40/60 limits for one platform.
- **`bc0c742`: the `--check` dry run now gets the arguments the real run gets.** This fixes the fault
  `Ship #6` exposed.
  - `ci-publish.sh` forwards `--tested`, and anything else it is given, to the dry run as well as to
    the real run.
  - `submit_build.py` now describes an `--archive-only` dry run rather than refusing one without
    `--apply`. `dry_run_plan` builds that description from the flags.
  - **Evidence:**
    - All six selftest suites green, 259 cases (`submit_build` 47).
    - With `--tested` ignored in memory, the new case fails.
    - Local dry runs on `bc0c742`. `--platform ios --tested` said "would reserve build 10025 … for
      ios", naming no test gate. `--platform macos --tested --archive-only` said "would stamp build
      10025 without reserving it … uploading nothing".
    - Origin's newest tag was still `build/10024` afterwards.
  - **Not yet observed:** `Verify` on `bc0c742`. TeamCity polls the repository, and minutes after the
    push it had not started.

**Learned while driving TeamCity from an agent session, 2026-09-10**

- **The sandbox exclusion matches only the plain command.**
  - Reaches the server: `python3 scripts/teamcity.py …`, including when piped into `head`.
  - Stays sandboxed, with ssh refused: the same command after a `TEAMCITY_CLI=` prefix, inside a
    shell loop, or inside `$(…)`.
  - So an agent session cannot poll TeamCity in the background. The owner says when a build has
    finished, and the agent reads it then.
  - Stretching the exclusion to run a loop unsandboxed was deliberately not done.
- **Some requests fail with "It said nothing at all, on either stream. ssh never reached the
  server."** This is not the sandbox refusal, whose message names the local machine. It happened
  three times; the two retried both succeeded at once.
- **`Ship` pins the tip of `main` when pressed.** A commit touching only `tasks/`, `.claude/` or
  `.mcp.json` has no `Verify`, because those paths are outside its trigger rules. Pressing `Ship` on
  such a commit queues a full `Verify` chain first, as `Ship #5` and `#6` both did. Avoid task-only
  pushes just before a press, or expect the wait.
- **`--check` stops after reporting its gaps, before the dry run.** On `all`, the missing installer
  identity means App Store Connect is never asked. Until the identity exists, `ship.platform = ios`
  is the way to reach the dry run.
- **A local `submit_build.py` dry run refuses a commit that is not on `origin/main`.** Push before
  dry-running a fix.
- **Both presses so far ran on `macstudio-3`.** Nothing yet decides which agent a press gets, and
  `macstudio-1` and `-2` are unproven for signing.

**Next, in order**

1. ~~Confirm the `6e0c2df` settings sync and a green `Verify` on it.~~ Done: `Verify #103` and
   `#104`, and `Ship`'s live settings match `cd64e4b`.
2. ~~Press `Ship` with `ship.args = --check`~~ Done as `Ship #5`: on `all` the installer identity
   was the one gap, so the dry run never started. The iOS `--check` that followed is `Ship #6`: green,
   and it planned build 10025. It also exposed the dropped `--tested`, fixed in `bc0c742`.
3. **With explicit owner approval, press `Ship` with `ship.platform = ios` and `ship.args` empty.**
   This is the first real delivery.
   - Once `Verify` is green on the tip of `main`, it reserves `build/10025` (or the next free number)
     and archives that commit.
   - It uploads, waits up to an hour for Apple, and delivers to the internal testers.
   - Afterwards, read the log, the `ship/record.json` artifact, App Store Connect, and Internal
     membership. Check the note's `Build N from <sha>` line names the pressed commit.
4. Import the Mac Installer Distribution identity (with its private key) for `nickpomfret`; press
   `ship.platform = macos` with `--archive-only` to prove the package signature and establish
   whether a macOS App Store profile has to be supplied; then a real macOS delivery.
5. Add the `finishBuildTrigger` on `Verify` (nightly included), then the composite `Verify`,
   Release compilation and test reporting.

**Acceptance criteria**

- [ ] A relevant main-branch push that passes verification produces an installable
  internal TestFlight build on both iOS and macOS without another distribution button.
- [ ] A failed verification prevents delivery. The archived SHA equals the verified SHA,
  even when main advances while Ship is queued or running.
- [ ] Both platform builds have correct versions, signing/provisioning, tester notes
  naming the archived commit, and confirmed internal-group membership.
- [ ] A missing or failing Homebrew setup cannot block Apple delivery. Apple delivery
  neither publishes a GitHub release nor edits the cask.
- [ ] Processing delays, rejection and timeouts produce useful diagnostics. Recovery
  selects the recorded build, does not duplicate an accepted upload, and does not
  relabel some newer build with an older commit's notes.
- [ ] Build selection/allocation handles pagination, expired builds and concurrent
  release attempts. Existing release provenance remains readable.
- [ ] Signing and macOS package export work on all agents eligible for Apple Ship;
  the design does not rely on a hand-made sibling checkout in one agent's `work/`.
- [ ] Final App Review submission remains manual. Homebrew can release independently,
  on a different cadence and without matching Apple version/build numbers.

**Validation already completed**

- [x] Read both projects' release scripts, Kotlin configuration and delivery docs.
- [x] Read live TeamCity settings and successful/failed release logs; inspected local
  LaunchAgent configuration and distribution-profile metadata.
- [x] Read live App Store Connect status for both apps.
- [x] No Spoilers' five Python selftest suites passed: 196 cases total.
- [x] Funmax's submit_build and testflight_distribute selftests passed.
- [ ] No fresh archive, export, upload or device installation was performed by this
  investigation. Those remain implementation acceptance work, not established results.

**Related records**

- [Task 36](36-teamcity-replaces-xcode-cloud.md): migration history; its combined
  three-channel release policy is superseded here.
- [Reusable Apple delivery patterns](../../agent-standards/docs/apple-testflight-delivery.md)
- [Full comparison](../docs/apple-release-comparison-2026-09-10.md)
- [Shared agent documentation](../../snowmonkey-proxy-common/docs/TEAMCITY-AGENTS.md)

The updated shared agent docs at `e845bec0` describe a temporary Homebrew tap clone.
This initially disagreed with local revision `be9b9873`; fetching before commit
revealed the implementation in `0c0db91`, now present locally at `95fdae2`. Preserve
that work when separating Homebrew. Its new clone path has been inspected, not run
by this investigation.

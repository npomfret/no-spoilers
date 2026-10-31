# Task 38: TestFlight delivery follows Funmax

**Status: DONE, 2026-10-31.** Unattended Apple delivery works and is proven, and `Verify` is hardened.

Make No Spoilers use the proven Super Funmax Music deployment pattern on the shared TeamCity agents:
verify a commit, archive that exact commit, upload it, wait for Apple processing, write its tester
notes, and confirm it is available to internal TestFlight testers.

**Scope**

- Funmax is the reference. Change No Spoilers to match; do not redesign Funmax here.
- Automation ends with an installable internal TestFlight build and correct notes, for iOS and
  macOS. Final App Review submission stays a manual button press.
- Homebrew is a separate flow, with its own trigger, credentials and cadence. Neither flow waits for
  the other, and their version and build numbers need not match.

**How it works now**

- `Ship iOS` (`ShipIos`) and `Ship macOS` (`ShipMacos`) each carry the VCS trigger, with
  `sync-revisions` and a snapshot dependency on `Verify` set to `CANCEL`. A relevant push queues both
  and pulls in one `Verify` at that revision. `Verify` itself has only the nightly schedule, so the
  nightly ships nothing.
- `scripts/ci-publish.sh --platform P --tested` asserts the agent and hands over to
  `scripts/submit_build.py`, which reserves a `build/N` tag, archives, uploads, waits, writes the note
  and reads back `Internal` membership.
- macOS signs manually with a local Mac Installer Distribution identity and the API-created
  `No Spoilers Mac App Store` profile, because Apple refuses the App Manager key cloud-managed
  certificates. iOS signs automatically.
- `.teamcity/cli.json` names `ShipIos` and `ShipMacos`. `docs/guides/building.md` explains the `status`
  window that can still hide them.

**Verify hardening, landed in `c12e6a7`**

`Verify` is a composite, `Verify: Xcode` also compiles both apps in Release, and `Verify: Swift tests`
reports JUnit results. The Python selftests write no JUnit output, so that leg reports none. A finished
`Verify` does not start `Ship`: that clause of the old plan is struck, because it shipped the nightly.

Read back from `Verify #193` (22011) at `4442dee`, started by a temporary schedule with the nightly's
flags, so on an unchanged revision: run by the build server with no agent; `Verify: Xcode #195` (22009)
ran all five steps, both Release steps under `Products/Release`; `Verify: Swift tests #193` (22010)
reported 149 tests passed. `Verify #192` at `c12e6a7` was queued before the settings applied, so it
ran the old steps and does not count. `ShipIos #24` (10050) and `ShipMacos #12` (10049) delivered from
it.

**Decisions, owner, 2026-10-31**

- A red `Verify` cancelling `Ship` is accepted on the live `CANCEL` setting. It has never been
  observed: the last red `Verify` is `#124` (nightly, 2026-09-16, no `Ship` waiting on it).
- Homebrew moved to `tasks/2026-10-31-homebrew-release-independently.md`.

**Acceptance criteria**

- [x] A relevant push that passes verification produces an installable internal build on both
  platforms with no further button. `ShipMacos #10` (build 10045) and `ShipIos #22` (10046) from
  `668df3d`.
- [x] The archived SHA equals the verified SHA when `main` advances. `62d6b58` was pushed at 11:35:59
  UTC while `ShipIos #16` was queued, and it still archived `ad2a77b` (`Verify #165`). Under the
  current trigger, `#22` and `ShipMacos #10` archived `668df3d` (`Verify #173`) with `main` already at
  `fe5d598`. Push times are from one Mac's reflog.
- [x] A failed verification prevents delivery. Accepted by the owner on the live `CANCEL` setting;
  not observed.
- [x] Both platform builds have correct versions, signing, notes naming the archived commit, and
  confirmed `Internal` membership.
- [x] A missing or failing Homebrew setup cannot block Apple delivery, and Apple delivery neither
  publishes a GitHub release nor edits the cask.
- [x] Processing delays, rejection and timeouts produce useful diagnostics, and recovery selects the
  recorded build. `ShipIos #18` names the closed train, and `#20`'s timeout is fixed in `16d158d`.
  Recovery's read path is proven live; see *Verification*. Its write path is residual risk.
- [x] Build allocation handles pagination, expired builds and concurrent attempts, and existing
  provenance stays readable.
- [x] Signing and macOS package export work on every eligible agent, proven by real deliveries:
  - `ShipMacos`: `macstudio-1` `#6`, `#10`; `macstudio-2` `#3`, `#4`, `#7`, `#9`; `macstudio-3` `#5`,
    `#8`.
  - `ShipIos`: `macstudio-1` `#21`, `#22`; `macstudio-2` `#19`; `macstudio-3` `#16`, `#17`.
- [x] Final App Review submission remains manual: nothing here submits.

**Verification**

- Recovery, read path, 2026-10-31: `testflight_distribute.py --platform ios --build 10044` and
  `--platform macos --build 10043`, without `--apply`, exit 0. Both builds are older than the newest
  on their platform (10046, 10045). Each run chose the named build, found its note names that build
  and commit, and found it in `Internal`, so nothing would be relabelled. The script has no upload
  path, so it cannot duplicate an accepted upload.
- `Verify` hardening, local: `scripts/verify-core-tests.sh` exit 0, with 149 tests and 0 failures in
  `tmp/test-results/NoSpoilersCore.xml`. `scripts/verify-ios-build.sh -configuration Release` built
  Release, widget included. A scratch package with one failing XCTest, run with the same flags, exited
  1 and reported 1 failure of 2. The macOS Release step, the JUnit parsing on TeamCity and the DSL
  are not proven until a chain runs.
- `TimeoutError` before reservation: `ShipIos #20` (id 12369, `9757c55`) died on one timed-out read
  in `next_build_number`, with a traceback and no record. Nothing was reserved, and `#21` shipped a
  newer build. `appstore_status.py --next-build` now asks up to three times, five then ten seconds
  apart, through `next_build`, starts no read past a 180-second deadline, and then says what failed.
  A stalled read begun at the deadline gives a worst case of 270 seconds, which `submit_build.py`'s
  selftest holds under its existing 300-second limit on `next_build_number`. Past that limit the helper
  stops with a message and whatever stderr it had; on success its stderr is passed on, so a recovered
  retry shows in `Ship`'s log. `transient` and `first_line` moved into `appstore_status.py`, so there
  is one retry judgement. Selftest cases cover a timeout, a 503, a 429, every attempt timing out, the
  exact pauses, both deadline stops, a 403 asked once, the limit's message and passed-on stderr.
- `scripts/verify-python-selftests.sh`, 2026-10-31: exit 0, every suite 0 failures
  (`appstore_status` 124 cases, `submit_build` 56). In a scratch copy, each of these fails a selftest:
  dropping `* attempt`, a longer pause, a fourth attempt, a later deadline, a longer `TIMEOUT`, either
  deadline check removed, stderr dropped, and `TimeoutExpired` left uncaught. No real `Ship` has run
  this code. `16d158d` holds it, unpushed.

**Residual risk**

- **Recovery's write path has never run for real.** Only a real failed delivery can prove
  `--apply` writing a missing note or group membership; staging one means a real upload left
  half-delivered, so it is not worth doing. Selftests cover it, and the next push ships a newer build
  anyway.
- `testflight_distribute.py` has no retry for network errors, and adding one to `asc_write.Session.get`
  would change every writer's reads, so it was left. Inside `Ship` such a failure is recorded with its
  recovery command.

- **`Ship` behind the composite is read, not observed:** the live dependency on `Verify` still has
  `CANCEL`, `sync-revisions` and successful builds only, and the next relevant push exercises it.
- The write lock went in `8e9d2a5`, so the two `Ship` configurations no longer queue behind each
  other. Two archiving together, and any overlap with Funmax's `Ship`, is unobserved. Reservation races are closed by `claim`.
- `teamcity.py builds` hides cancelled builds, so `ShipMacos #2` is unaccounted for.

Follow-ups moved to `tasks/2026-10-31-testflight-follow-ups.md`.

**Related records**

- [Reusable Apple delivery patterns](../../agent-standards/docs/apple-testflight-delivery.md)
- [Full comparison](../docs/apple-release-comparison-2026-09-10.md)
- [Shared agent documentation](../../snowmonkey-proxy-common/docs/TEAMCITY-AGENTS.md)

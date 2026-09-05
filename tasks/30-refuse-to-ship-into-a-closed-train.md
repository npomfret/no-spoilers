# Task 30: refuse to ship a version App Store Connect has already approved

**Status: FILED, 2026-09-05. Not started.**

## The issue

Three `Publish iOS` runs on TeamCity failed today (builds 18, 19 and 20, at 15:26, 15:33 and
17:42 UTC), each pressed with `publish.args` empty, so each shipped the version the project holds,
1.1.2. Version 1.1.2 is the one Apple approved on 2026-09-04 and is on the store. App Store Connect
closes a train once its version is approved, so `altool --validate-app` refused each package with
two errors at once:

- `90186` Invalid Pre-Release Train. The train version '1.1.2' is closed for new build submissions
- `90062` CFBundleShortVersionString [1.1.2] must contain a higher version than that of the
  previously approved version [1.1.2]

Every run got that far: the tests passed, the archive succeeded, the export succeeded, and
`release.sh` committed and pushed its bump between the two. So `main` now carries `d3930d0`,
`e7a6fd7` and `04c7bf4` — bumps to builds 10019, 10020 and 10021 that describe artifacts Apple
never received. Harmless, since build numbers only have to increase, but each one is the same
misleading commit `docs/guides/building.md` already describes under *A failed export still leaves a
pushed bump commit*, and three of them cost about five minutes of agent time and one write lock
each to learn something one GET could have said before the archive.

Why the existing preflight let it through: `release.sh` asks App Store Connect one question before
building, via `appstore_status.py --spent PLATFORM VERSION BUILD` — is this `(version, build)` pair
already held? `train_builds` reads every build on the platform joined to its `preReleaseVersion`.
Build 10019 was not in train 1.1.2, so the answer was "free", and the check is right: the number
*is* free. What it never asks is whether the train itself will still accept a build. That is a
property of the `appStoreVersions` record for 1.1.2 — its `appStoreState` — not of the builds in
the train, and nothing on the release path reads it. `gather` does, for the status report, and
`SHIPPED` at `appstore_status.py:131` already names exactly the states that mean a version has
reached the store.

## Brainstorming

- **Widen `--spent` to answer both questions (recommended).** Before comparing build numbers, read
  the platform's `appStoreVersions`, and if one with `versionString == VERSION` is in `SHIPPED`,
  print that the train is closed and exit `SPENT_EXIT`. Same flag, same exit contract, same call
  site in `release.sh`, so the shell side changes only its wording: "spent" now means "Apple would
  refuse this pair", for either reason. Cost: one more GET on the release path and a handful of
  selftest cases against fixture JSON. This is the smallest change that stops the archive and the
  bump commit.
- **A second flag, `--train-open`.** Two questions, two flags, two exit codes to teach the shell.
  Cleaner to read and more surface to keep consistent; `release.sh` would gain a second block that
  reads identically to the first. Rejected: the caller only ever wants the conjunction.
- **Have `ci-publish-ios.sh` require `publish.args`.** Would have stopped today's three, but it
  would also stop the ordinary case the script's own usage comment documents — shipping "the
  version the project holds" while a train is open and builds are still going to TestFlight — and
  it does nothing for the laptop path through `ship-ios.sh`. Rejected as a fix, though see the plan:
  the TeamCity log line can say what version it is shipping *and* why.
- **Bump the marketing version automatically when the train is closed.** Turns a refusal into a
  guess about which digit to increment, and a release script that opens a train nobody asked for is
  worse than one that stops. Rejected; `release.sh` already says "stopping rather than guessing".
- **Move the bump commit after the upload.** Would remove the stray commits for every failure mode
  at once, and is the durable form of the *A failed export still leaves a pushed bump commit* note.
  But it changes the reasoning that commit records ("the build number is real once archived") and
  the rebase-on-push logic around it, for a benefit this task can get by never reaching the
  archive. Out of scope; noted so it is not lost.

## The plan

1. **Make `--spent` refuse a closed train.** In `appstore_status.py`, a pure function
   `train_closed(versions: list[dict], platform_flag: str, version: str) -> bool` over the
   `appStoreVersions` payload, true when a record for that platform and `versionString` has an
   `appStoreState` in `SHIPPED`. `main`'s `--spent` branch calls it before `train_builds`, prints
   `ios 1.1.2 is closed: READY_FOR_SALE since <createdDate>` (or the state it found) and returns
   `SPENT_EXIT`. Done when `--selftest` covers: open train, shipped train, the same version shipped
   on the *other* platform only (must stay open), no record at all (open), and
   `REPLACED_WITH_NEW_VERSION` (closed).
2. **Say the right thing in `release.sh`.** The `3)` case at `scripts/release.sh:275` currently
   says "That build number is already used in this version". It has to cover both answers without
   guessing which: print the line Python printed and then "Pick another build with --build, or open
   a new train by shipping a different version. Nothing was built." Done when the wording does not
   claim the build number when the train was the problem.
3. **Prove it against the real record.** From the laptop, with the key present:
   `scripts/appstore_status.py --spent ios 1.1.2 10022` exits 3 and names the state;
   `--spent ios 1.1.3 1` exits 0. Record both lines here. This is a read; it uploads nothing.
4. **Say so in the docs.** `docs/guides/building.md`: the paragraph beginning *A spent (version,
   build) pair does not fail the build* under the release engine gains the closed-train case and
   today's three builds as the counter-example; the `ci-publish-ios.sh` usage comment gets one line
   saying that an empty `publish.args` after an approval will be refused before the archive, and
   what to press instead.

## Tracking

- Filed from the TeamCity logs of builds 3082, 3091 and 3106 (`NoSpoilers_PublishIos` #18–#20),
  read over the SSH tunnel on 2026-09-05. Each failed in `altool --validate-app` inside
  `release.sh`; the TeamCity side is healthy.
- The immediate release is not this task: `Publish iOS` with `publish.args = 1.1.3` opens the new
  train and ships the Live Activity fix and dark mode.

Verification:

- [ ] `scripts/verify-python-selftests.sh` passes with the new cases
- [ ] `--spent ios 1.1.2 <free number>` exits 3 naming the state; `--spent ios 1.1.3 1` exits 0
- [ ] `docs/guides/building.md` and the `ci-publish-ios.sh` comment carry the case

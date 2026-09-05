# Task 32: tag builds and approvals, and stop committing the build number

**Status: BUILT, 2026-09-05. Steps 1–5 landed and `ios/v1.1.2` is on origin; awaiting the first
`Publish iOS` press and a `ship.sh` run.**

## The issue

Two things about the numbering are not what they claim to be, and both come from the same
design: `release.sh` records an upload by committing the project file.

- **The version tag marks the first upload of a train, not what users got.** `v1.1.2` points at
  `bump to v1.1.2 (build 10003)`; the build on sale is 10012. `v1.1.3` now points at 10022, the
  first upload of a train that will hold a dozen more before one is approved. Anyone starting a
  bisect or a diff from a version tag starts from the wrong commit, and nothing in the repository
  says which commit *is* on the store.
- **Every TestFlight upload is a commit on `main`.** Twenty `bump to` commits since 2026-08-22,
  three of them (10019–10021) for builds Apple never received. The `Built-From:` trailer and the
  rebase-and-retry push exist only because that commit has to land on a moving branch; the
  trailer is a fact about the archive that a tag on the archived commit would state directly.
- **`CURRENT_PROJECT_VERSION` in the project file is a ledger, not a build setting.** The
  archive is already stamped from the command line (`CURRENT_PROJECT_VERSION="${NEW_BUILD}"`), so
  the committed value's only job is to remember the last number, and its self-checking setter
  exists to keep the app and the widget extension agreeing about a value the archive overrides
  anyway.

Best practice on all three: CFBundleVersion is a monotonic counter whose authority is the thing
that enforces it, App Store Connect; each upload is a tag on the commit it was built from; the
version tag is created once, when users can get that build, on that build's commit.

## Brainstorming

- **Annotated `build/N` tag per upload, counter from App Store Connect, version tag at approval
  (chosen).** `appstore_status.py` already reads every build on both platforms (`train_builds`),
  so the next number is the highest it holds plus one, on either platform and in every train,
  live or expired. The tag goes on `HEAD` after the archive, which is the commit that was built,
  so provenance needs no trailer and the tag push cannot race `main`. Approval is a fact only
  App Store Connect knows, and `ci-publish-ios.sh` already learns it at the exact moment it
  matters, when `--train` says the version is closed; that is where the approval tag is written.
- **Derive the number from git (`git rev-list --count HEAD`, 373 today, plus an offset).**
  Identifies the commit for free and needs no network. Rejected: a second press on the same
  commit, which is the ordinary way to retry a failed upload, would produce the same number and
  be refused as spent; and the number becomes wrong the day history is rewritten.
- **Keep the counter in the project file but write it with a tag instead of a commit.** A tag
  cannot carry a file change, so the next run would read a stale file. Rejected; the file is the
  problem.
- **Move the existing `vX.Y.Z` tags onto the approved builds.** Rewrites 26 published tags that
  the Homebrew cask URL and the GitHub releases depend on. Rejected; they stay and are documented
  as history.
- **One bare `vX.Y.Z` tag for the approval.** The platforms are approved at different builds
  (iOS 1.1.2 at 10012; macOS 1.1.2 is not even submitted), so one name cannot point at both.
  Rejected in favour of `ios/vX.Y.Z` and `macos/vX.Y.Z`.

## The plan

Each step leaves every current caller working; the bump-commit history stays readable throughout.

1. **`appstore_status.py --next-build`** prints the highest build number App Store Connect holds
   on either platform plus one; **`--approved PLATFORM VERSION`** prints the build number a
   READY_FOR_SALE version carries. Both share the `--spent`/`--train` exit contract: 0 answered,
   1 the check failed. Selftests for both against fixture records, including an expired build and
   a build from the low Xcode Cloud band beside a 10000-band one.
2. **`release.sh` stops committing the build number.** The number comes from `--next-build`
   unless `--build` pins it (`ship.sh` moves to `--next-build` too, one number per ship run as
   today). `set_build_number` is no longer called here; it stays for `ci_pre_xcodebuild.sh`. The
   archive is stamped from the command line as now, and the exported package is checked
   afterwards: the app's and the extension's `Info.plist` must both read `N`, or the run stops
   before the upload. After the archive, an annotated `build/N` tag is written on `HEAD` and
   pushed, in the slot the bump commit occupies today and for the same reason: an uploaded build
   must be recorded even if the upload then fails. `MARKETING_VERSION` is still committed, but
   only when it changed, as `open vX.Y.Z`; the rebase-and-retry push stays for that commit and
   the `Built-From:` trailer goes, since the tag says what was built. The committed
   `CURRENT_PROJECT_VERSION` is frozen at 10022 and never lowered.
3. **`vX.Y.Z` is created at the moment users can get the build.** For the Developer ID channel
   that is the run itself, so `tag_version` stays on that channel only, now annotated, because
   the cask URL (`releases/download/v#{version}/…`) depends on the name. The App Store channels no
   longer tag at upload. A new `scripts/tag-approved.sh PLATFORM VERSION` asks `--approved`, finds
   `build/N`, and writes an annotated `PLATFORM/vX.Y.Z` on the same commit; `ci-publish-ios.sh`
   runs it for iOS when `--train` reports the version closed, before opening the next one, and a
   person runs it for macOS. `suggest_next_version` reads `v*`, `ios/v*` and `macos/v*`.
4. **`testflight_distribute.py: ship_commit`** reads `build/N` first and falls back to the
   `bump to` grep and the `Built-From:` trailer for 10001–10022, which are never re-tagged.
   Selftests cover a tag-only build, a bump-only build, and both present with the same answer.
5. **Docs.** `docs/guides/building.md` (the numbering section, the two bands, what each tag
   means and since when), `docs/guides/important-code.md` items 20, 23 and 39, and the
   `release-and-delivery` skill.

## Tracking

Decisions taken at filing and kept:

- The bare `vX.Y.Z` keeps one meaning going forward, the Developer ID release, because the
  Homebrew cask URL is built from it. The 26 existing bare tags mean "first upload of the train"
  and are left alone.
- A second press on an unchanged commit gets a new number and a second `build/` tag on the same
  commit. That is the honest record, and it is the same case the TestFlight note already handles
  as "a re-ship with no work in between".
- `git fetch --tags` is required wherever `build/` tags are read; `next_build_number`,
  `release.sh`'s preflight, `testflight_distribute.py` and `tag_approved.py` each fetch first.

Where the build departed from the plan, and why (2026-09-05):

- **The `open vX.Y.Z` commit is pushed before the archive, not after.** The plan kept the
  bump commit's slot. Moving it first is what makes `ship.sh` work: the macOS run commits the
  version and tags `build/N`, and the iOS run has to find that tag on its own `HEAD`, which it
  cannot if the version commit lands after the tag. It also retires the `Built-From:` reasoning
  entirely — a rebase can now only reorder what is about to be built — and a failed archive
  leaving `open v1.1.4` on `main` is an honest statement about the project.
- **The archive is checked, not the exported package.** The export re-signs what the archive
  holds and rewrites nothing, and checking the archive catches a wrong number before the tag as
  well as before the upload. Every `.app` and `.appex` under `Products/Applications` must read N;
  iOS must hold two bundles, macOS holds one (the Mac target embeds no extension).
- **The next number is the higher of App Store Connect's and the `build/` tags', plus one.**
  A tagged number that never reached the record — a Developer ID release, or an upload that
  failed after the tag — would otherwise come back and be refused at `git tag`, after the
  archive. `next_build_number` in `_version.sh` holds that rule for `release.sh` and `ship.sh`.
- **`scripts/tag_approved.py`, not `tag-approved.sh`.** The lookup it needs — tag first, bump
  commit and trailer for 10001–10022 — is `ship_commit` in `testflight_distribute.py`, and a
  shell copy of it would be the second implementation the rules forbid. It imports that and
  `approved_build`, dry-runs by default, and `ci-publish-ios.sh --check` dry-runs it too.
- `--approved` exits 3 for a version not on the store, alongside `--spent` and `--train`'s 3.

Verification:

- [x] `scripts/verify-python-selftests.sh` green: appstore_status 123 cases (11 new, for
      `approved_build` and `highest_build`), testflight_distribute 38 (4 new, `ship_commit`
      against a throwaway repository: tag alone, bump alone, both, neither), tag_approved 7
- [x] `--next-build` against the real record printed 10023
- [x] `--approved ios 1.1.2` against the real record printed 10012; `--approved macos 1.1.2`
      exited 3 (not submitted)
- [x] `tag_approved.py ios 1.1.2` dry run: "build 10012 was archived from ed1951b612c9 … would
      tag ios/v1.1.2 there"
- [x] `tag_approved.py ios 1.1.2 --apply` wrote `ios/v1.1.2` on ed1951b (build 10012's Built-From
      commit) and pushed it, 2026-09-05; a second run reported it already there
- [x] One `Publish iOS` press with `publish.args` empty — build 23, 2026-09-05 19:46–19:49 UTC,
      green: `--next-build` chose 10023, the version was unchanged and nothing was committed,
      the log shows `NoSpoilersApp.app: 10023` and its widget extension at 10023, `build/10023`
      is on origin pointing at `bf44f3d` (the archived commit, still `origin/main`), and once
      Apple had processed the build the note reader's dry run said *Would set 'Build 10023 from
      bf44f3d22e31', from the build/10023 tag*. The note itself is written by
      `testflight_distribute.py --apply`, which is the delivery step and a separate decision.
      Xcode Cloud is uploading again — iOS build 100 landed ten minutes before this one — so
      both bands are live on the record at once, as documented.
- [ ] A `ship.sh` run (task 26) with one number on both platforms, taken from `next_build_number`

Residual risk: a rewritten history moves what `build/` tags point at, exactly as it moved what
bump commits pointed at; nothing new. The `--next-build` question adds one GET to a run that
already makes two. `ci-publish-ios.sh --check` was not run from this laptop because it rewrites
`origin`'s push URL; the shell is syntax-checked and the branch it changed is the closed-train
one, which the next press after an approval will exercise.

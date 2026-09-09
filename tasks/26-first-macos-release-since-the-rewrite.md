# Task 26: the first macOS release since the release engine was rewritten

**Status: IN PROGRESS, narrowed. Raised 2026-09-05 out of task 22. The Mac App Store half is
done — 1.1.3 is on the store and tagged — but it shipped from an Xcode Cloud build, so neither
of the two things this task exists to exercise has run. What remains is the Developer ID /
Homebrew channel, still at 1.1.1 since 2026-08-12, and the one-build-number path through
`ship.sh`. Both are now owed at 1.1.4, not 1.1.3. Everything else this task listed is done.**

`scripts/release.sh` was rewritten on 2026-08-13 and 2026-08-14. Since then the iOS App Store
channel has shipped fifteen builds (locally and from TeamCity) and the macOS App Store channel
uploaded `1.1.2 build 10006` on 2026-08-23. Two things have still not run under the current script:

- **The Developer ID channel.** Notarised zip, GitHub release, Homebrew tap. Its last run was
  `v1.1.1` on 2026-08-12, the day before the rewrite. `../homebrew-tap` and the GitHub releases
  still sit at 1.1.1.
- **`scripts/ship.sh` putting one version and one build number on all three channels in one run.**
  The one-build-number fix exists because the 2026-08-12 run produced 10001 on macOS and 10002 on
  iOS; the fix has never shipped anything.

Nothing here is suspected broken. Do not rehearse it; the next macOS release exercises it, and
`docs/guides/building.md` is where anything it turns out to be wrong about gets corrected.

## Before that build is made

**Photograph the popover first.** It has carried a bundled wordmark face since 2026-08-26
(`BrandTypeface`) that has never been seen on macOS: the build is green and the Core tests register
the font in a macOS process, but no one has looked at the pixels. `mac_screenshots.py` quits
whatever is in the menu bar and launches the app it is given, which is why it was not done while
the shipped app was live. If the face failed to load, the wordmark renders in the system font and
nothing anywhere reports it.

## Verification

- [ ] `ship.sh` run: same version and build number on Mac App Store, Developer ID and iOS. Since
      task 32 (2026-09-05) the number comes from `next_build_number` once, the macOS run writes
      `build/N` and the annotated `vX.Y.Z`, and the iOS run finds `build/N` already on its
      commit — this is the first run to exercise that reuse path
- [x] Dropped: `scripts/ci_health.py` was deleted with the Xcode Cloud path (task 36), so there
      are no products left to resolve
- [x] Popover photographed with the Chivo wordmark before the archive — 2026-09-06, light and
      dark, from a `verify-mac-build.sh` build of 1.1.3/10022. The face loads; it is not the
      system font
- [x] The release note says the app now follows the system appearance (task 28, 2026-09-05,
      asked for both): `listing/macos/whats-new.txt`, second bullet

## 2026-09-06: what the release is, measured

- **On the store: macOS 1.0.21, build 2**, approved 2026-04-25 (`appstore_status.py --approved
  macos 1.0.21`). `tag_approved.py macos 1.0.21` resolves it to `6991ff4` and has not been
  applied. The Resolution Center is quiet (the one macOS thread is the April 1.0.13 rejection),
  App Privacy is published, and the inbox is empty.
- **The 1.1.2 macOS record is still `PREPARE_FOR_SUBMISSION` holding 10006**, created 2026-08-22,
  never submitted. The project is at 1.1.3 and iOS 10023 is already uploaded on that train, so the
  Mac ships 1.1.3. App Store Connect allows one version in preparation per platform, so the record
  has to be **renamed** 1.1.2 → 1.1.3 (a `PATCH` of `versionString`, which `appstore_listing.py`
  does not do yet) rather than created beside it.
- **Not cosmetic.** Since 1.0.21 the Mac target and Core have taken 95 commits across 43 files:
  session alerts (a new notification permission), the trademark sweep (the wordmark is gone from
  the menu bar and the popover), the token palette and dark mode, the Chivo wordmark, the
  finished-badge rollover into days, one URLSession policy, structured logging, and the unmapped-GP
  crash fix. Entitlements are unchanged since 1.0.21 and the GitHub update check is already gated
  off by the receipt in App Store builds. Relative to the never-submitted 10006 the increment *is*
  cosmetic: the wordmark face, dark mode and the days rollover.
- `listing/macos/{whats-new,description,review-notes}.txt` rewritten for 1.0.21 → 1.1.3. The
  bullet "marked safe to watch using the time the session actually ended, rather than an
  estimate" was dropped: 1.0.21's `ContentView` already read `store.confirmedEndDates`, so on the
  Mac that is not new. Dry run against the record: keywords already correct, the other three
  change, no trademark hits.

## Order of work for 1.1.3 — spent

All four steps ran, but step 2 did not: the build that shipped was Xcode Cloud's 104, not a
`release.sh` archive. **Do not follow this list.** The project is at 1.1.4 (`MARKETING_VERSION`,
`dee65fc`), so the release still owed here is 1.1.4 — see the last section.

1. `scripts/mac_screenshots.py` — photograph the popover light and dark (the precondition above).
2. `scripts/release.sh 1.1.3 --platform macos --channel both` (or the full `ship.sh 1.1.3`, which
   would upload iOS again beside 10023). Needs a clean tree: `.claude/settings.json` is modified.
3. Rename the 1.1.2 record to 1.1.3, then `appstore_listing.py --platform macos --version 1.1.3
   --build N --apply`, then `testflight_distribute.py --platform macos --apply`.
4. Submit in the browser. Afterwards `tag_approved.py macos 1.1.3 --apply`.

## 2026-09-06, later: done so far

- `appstore_listing.py --rename` added (one `PATCH` of `versionString`, mutually exclusive with
  `--create`; selftest 15 cases). Applied: the macOS record is now **1.1.3, `PREPARE_FOR_SUBMISSION`,
  build 104** (Xcode Cloud, 1.1.3), with the rewritten description, what's new and review notes
  written and the demo account cleared. Not submitted.
- Popover photographed light and dark from a `verify-mac-build.sh` build of this checkout
  (1.1.3, 10022) into `tmp/screenshots/1.1.3/`: the Chivo wordmark renders in both, dark draws
  charcoal surfaces and ivory text. The desktop behind is an IDE, so they verify the build and are
  not listing images; a listing shot needs a plain desktop first.
- Still open: whether 104 or a `release.sh` build ships (the 10000 band has not been used for this
  version on macOS), the Developer ID / Homebrew channel at 1.1.1, `tag_approved.py macos 1.0.21`,
  and Submit.

## 2026-09-06, later still: the screenshot

The record's one desktop image was the Gemini mock-up carried over from 1.0.21 — the owned logo in
the menu bar and the popover header, plus a Homebrew update banner. Replaced with two real captures
of the 1.1.3 build, light and dark, made without a plain desktop: the popover and the status item
were cut out of the capture by their Accessibility frames (the popover *window* frame carries
about 13pt of shadow margin and the arrow, so the crop is inset to the visible body) and placed on
a plain slate ground with a drawn shadow. `appstore_screenshots.py` learned the `APP_DESKTOP`
slot (2560x1600). The composition is now `mac_screenshots.py --mask`, CoreGraphics through the osascript
JavaScript bridge so the script stays stdlib-only.

Build 104 also went to Internal (`testflight_distribute.py --platform macos --build 104`).
Everything Submit needs is now on the record; Submit itself is still a person.

## 2026-09-06: submitted

macOS 1.1.3 build 104 went to App Review at 2026-09-06, `WAITING_FOR_REVIEW`. When it is
approved: `tag_approved.py macos 1.1.3 --apply`, and decide the Developer ID / Homebrew channel,
which is still at 1.1.1.

## 2026-09-09: approved, and what is actually left

Build 104 was approved 2026-09-07 and is `READY_FOR_SALE`. `tag_approved.py macos 1.1.3 --apply`
ran 2026-09-09 and wrote `macos/v1.1.3` on `dc2f283919d3` — from the build's TestFlight note,
because an Xcode Cloud build leaves no `build/N` tag.

Which is the point. **The Mac App Store shipped without either of the two things this task exists
to exercise.** 104 came from Xcode Cloud, so `release.sh` did not archive it, `ship.sh` did not
put one number on three channels, and the Developer ID channel was never in the run at all. The
task therefore narrows rather than closes:

- **The Developer ID channel is at 1.1.1** — GitHub release `v1.1.1`, 2026-08-12, and
  `../homebrew-tap` cask `version "1.1.1"`. Nothing has been notarised since the engine was
  rewritten the following day.
- **`ship.sh`'s one-build-number path has still never run.** It is the fix for the 2026-08-12
  run that produced 10006 on macOS and 10002 on iOS, and it has shipped nothing.
- ~~**`tag_approved.py macos 1.0.21`** was never applied.~~ **Done 2026-09-09:** `macos/v1.0.21`
  is on `6991ff4`, annotated and pushed. See the last section for why that is not the commit the
  bare `v1.0.21` marks.

### A trap in front of the Developer ID run, now cleared

`release.sh:377 tag_version` writes the bare `vX.Y.Z` for the Developer ID channel and *skips*
when the name already exists, then pushes what is there. `v1.1.2` and `v1.1.3` already existed —
written by the pre-task-32 `release.sh`, which tagged the bare name at the first upload of a
train whatever the channel:

    v1.1.2  6c304c611de8  "bump to v1.1.2 (build 10003)"   2026-08-22
    v1.1.3  a5017d8ac464  "bump to v1.1.3 (build 10022)"   2026-09-05

So a Developer ID release of 1.1.3 would have silently reused a tag marking the *bump* commit
rather than the notarised one — the same defect on the Homebrew channel that task 32 fixed on
the App Store channels.

**Both were deleted 2026-09-09**, from this checkout and from `origin`, because neither was ever
a Developer ID release: there is no GitHub release on either name (the newest is `v1.1.1`,
2026-08-12) and the cask has never pointed at them. Deleting rather than moving, because moving
a published tag is what `tag_approved.py` refuses to do and this should not do either. Both
commits are on `main` and nothing was orphaned; the SHAs above restore either tag.

Checked before deleting, and each of these is why it was safe:

- No GitHub release on `v1.1.2` or `v1.1.3`; `../homebrew-tap` is at `1.1.1`.
- `_version.sh:tagged_versions` unions all three families, and `ios/v1.1.2`, `ios/v1.1.3` and
  `macos/v1.1.3` still cover both versions — so `suggest_next_version` and `version_tagged`
  answer exactly as before.
- The only other reader of a bare name is `release.sh:378`, and its skip is the behaviour being
  removed. `testflight_distribute.py:418` matches the *commit subject* `bump to vX.Y.Z`, not a
  tag, so `ship_commit` still resolves builds 10001–10022.

`v1.0.10` and `v1.0.11` were deleted the same day, for the same reason: no release, no cask
reference, no mention anywhere in either repository. They are two gaps in an otherwise unbroken
run of releases made on 2026-03-29, which reads as two attempts that were superseded within the
hour. `v1.0.11` marked its own `bump to v1.0.11` commit, so that version is still named in
history; `v1.0.10` marked `add LSApplicationCategoryType for App Store submission`, and the tag
was the only place that version was written down. `280d76b0637a` and `b4b245e334d3` restore
them.

**What this leaves is an invariant, and it is the useful part.** Every bare `vX.Y.Z` tag now has
a GitHub release of the same name, and every release has its tag — 22 of each, checked both
directions on 2026-09-09 with no orphan either way. A bare tag with nothing behind it is from
here a defect rather than history, which is what makes `tag_version`'s skip safe again.

## 2026-09-09: what App Store Connect actually holds, and the version this task now owes

Read from `appstore_status.py`, not from git, because the two disagree about what is newest.

- **macOS 1.1.3 build 104 and iOS 1.1.3 build 112 are both `READY_FOR_SALE`.** Those are the only
  two version records on the app; there is no 1.1.4 record in preparation on either platform, and
  `--train macos 1.1.4` says the train is still taking builds. The report's own verdict is
  "Nothing this report can see is waiting on you."
- **`--approved macos 1.0.21` resolves to build 2**, so the outstanding
  `tag_approved.py macos 1.0.21 --apply` still has something to name. It has not been applied.

**The newest upload is not the highest build number, and here that gap is four digits wide.**
TestFlight reports the newest build as **131 on both platforms**, with testers on **118**, four
builds back in a five-build search window. `--next-build` is **10024** — it takes the highest
number App Store Connect holds in any train, which is still `build/10023` from 2026-09-05. So
Xcode Cloud went on uploading to both platforms after that tag, in its own low-numbered band,
and those builds are the most recent things the store has. They carry no `build/N` tag, so
**nothing in this repository can name the commit behind any of them**, and the CI that made them
no longer exists. Four of them, macOS included, have never been distributed to the Internal group.

Which build numbers those are was not visible in that report — it searches only the newest five,
and build numbers are not contiguous, so the range could not be inferred from 118 and 131.
Enumerated properly they are **127, 128, 130 and 131 on each platform**, all uploaded 2026-09-09,
the last Xcode Cloud runs before the workflow was disabled. 119–126 and 129 were consumed by runs
that delivered nothing, which is the hole-making `train_builds` describes.

### Expired, 2026-09-09

All eight are now expired, on both platforms, by
`testflight_distribute.py --platform <p> --expire 1.1.4 --apply`. TestFlight now reports 118 as
the newest build on both platforms and installable — the four-builds-behind gap is closed.

**`--next-build` is still 10024.** Expiring stops a build launching; it does not free its number,
which is why `highest_build` counts expired builds. So this changed what a tester can install and
nothing about the next release.

The `--expire` mode is new, in `testflight_distribute.py` because that script already owns
TestFlight build state and already writes through `asc_write`. **What makes it safe is its
definition of an orphan: a build no tester group holds and no `appStoreVersions` record points
at.** Both halves are read from App Store Connect per run, not assumed, and anything failing
either test is listed with the reason and left alone. Deliberately not "old", "superseded" or
"untagged" — those say how a build got here, only these two say whether expiring it takes
something away from somebody.

Checked against 1.1.3 before the write, which is the case that must refuse: of its 22 unexpired
builds it kept iOS 112 as *attached to an App Store version record* and every build the Internal
group holds, including 10022 and 10023. Verification: `verify-python-selftests.sh`, five scripts
green, 48 cases in this one.

Nothing about this rescues the task. An Xcode Cloud upload is exactly what task 26 exists not to
be satisfied by, and none of these are Developer ID builds. It changes two practical things:

- **The release still owed is 1.1.4**, at build 10024 from `--next-build`. The macOS App Store
  half would be exercised again by the same run, because 1.1.4 has no record yet — so a `ship.sh`
  run now covers all three channels and both of the things this task was raised to test.
- **The orphan builds are expired** (above), so the newest installable build on both platforms is
  118 again and nothing a tester can reach comes from the dead CI.

### `macos/v1.0.21`, and the two commits of one version

Applied 2026-09-09: `macos/v1.0.21` on **`6991ff4`**, pushed. That is what Mac users who never
updated are still running, and until now it was written down nowhere.

**It is not the commit the bare `v1.0.21` marks, and that is the point of having two families.**
The bare tag — the Developer ID release behind GitHub release `v1.0.21` and the Homebrew cask —
is on `e070608 bump to v1.0.21`, 14:04:43. The App Store build was archived nine minutes later,
from `6991ff4`, and shipped as build 2. One version, two channels, two commits: exactly the
conflation task 32 fixed by giving the App Store its own `PLATFORM/vX.Y.Z` family.

The resolution has no guesswork in it and was checked before applying. There is no `build/2` tag
— those start at task 32 — so `ship_commit` fell to the `bump to v1.0.21 (build 2)` commit,
`4192002` at 14:16:23, exactly one in the repository, and returned **its parent** rather than the
bump itself. Parentage is the honest answer for any bump before 2026-08-26, the day `release.sh`
learned to rebase them; this one is from April. 1.0.21 also produced builds 3 and 4 that same
afternoon, and the store approved build 2, so the other two bumps are correctly not what was read.

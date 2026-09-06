# Task 26: the first macOS release since the release engine was rewritten

**Status: WAITING for a macOS release to be wanted. Raised 2026-09-05 out of task 22.**

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
- [ ] `scripts/ci_health.py` still PASS afterwards, both products resolving by id
- [ ] Popover photographed with the Chivo wordmark before the archive
- [ ] Popover photographed dark as well, and the release note says the app now follows the
      system appearance (task 28, 2026-09-05, asked for both)

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

## Order of work for 1.1.3

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

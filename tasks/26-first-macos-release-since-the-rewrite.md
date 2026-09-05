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

---
name: release-and-delivery
description: Use only when the user explicitly asks to release, ship, distribute TestFlight, submit to App Store Connect, inspect Xcode Cloud delivery, or capture App Store screenshots. Preserves the repo's deliberate read/write and release-channel boundaries. Do not use for ordinary builds or tests.
user-invocable: true
disable-model-invocation: true
---

# Release And Delivery

## Required flow

1. Read `docs/guides/building.md`, `docs/guides/important-code.md`, and the relevant release or task document before running any delivery command.
2. Inspect the working tree, current branch, and the actual wrapper or Python script. Do not infer a release path from an old task or command history.
3. Classify the requested action before proceeding:
   - read-only status: `scripts/appstore_status.py` or `scripts/ci_health.py`
   - TestFlight distribution: `scripts/testflight_distribute.py --apply`
   - App Store listing copy or version metadata: edit `listing/<platform>/*.txt`, then `scripts/appstore_listing.py --platform <p> --apply`
   - Store or Homebrew release: one of `scripts/ship*.sh`
   - deterministic listing screenshots: `scripts/screenshots.py` (iOS, simulator) or `scripts/mac_screenshots.py` (macOS, the real app on this machine)
4. Treat every action other than the two status scripts and screenshot dry runs as an external write. Confirm the exact platform, channel, version, tester group, and release intent from the user when any is ambiguous.
5. Preserve existing boundaries: releases run locally, Xcode Cloud does not distribute to testers automatically, `appstore_status.py` remains read-only, `testflight_distribute.py` is the only thing that writes TestFlight metadata or groups, and `appstore_listing.py` is the only thing that writes App Store listing copy. Never edit listing copy in the App Store Connect web form — it is checked in, and a web edit is a silent divergence from the repository.
6. Never submit anything for App Review. No tool here does it and none should: it is a person pressing Submit.
7. For screenshots, follow the script docstring and `docs/guides/building.md`; never launch the app after seeding a fixture.
8. Report the exact command, external effect, and any manual follow-up. Never claim store or TestFlight delivery from a green local build alone.

## Do not

- Do not reintroduce a CI release path or a second release engine.
- Do not guess credentials, App Store Connect IDs, Xcode Cloud product IDs, build numbers, groups, or release channels.
- Do not treat the highest build number as the newest upload.

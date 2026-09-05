---
name: release-and-delivery
description: Use automatically only when the user explicitly asks to inspect or change App Review, App Store Connect, TestFlight, TeamCity publishing, release delivery, or listing screenshots. Preserves remote read/write boundaries. Do not infer release intent from a successful build or completed feature.
user-invocable: true
---

# Release And Delivery

## Required flow

1. Read the relevant section of `docs/guides/building.md`, the owning script's docstring, and the
   active release task before running a delivery command. Use `docs/guides/important-code.md` only
   when ownership is unclear.
2. Inspect the working tree, current branch, and the actual wrapper or Python script. Do not infer a release path from an old task or command history.
3. Classify the requested action before proceeding:
   - read-only status: `scripts/appstore_status.py` or `scripts/ci_health.py`
   - App Review conversation or reply: from sibling repo `../appstoreconnect-bot`, run
     `node dist/cli.js report 6761343835`; never read its `tmp/curl.txt`
   - TestFlight distribution: `scripts/testflight_distribute.py --apply`
   - App Store listing copy or version metadata: edit `listing/<platform>/*.txt`, then `scripts/appstore_listing.py --platform <p> --apply`
   - Store or Homebrew release: one of `scripts/ship*.sh`
   - TeamCity iPhone publish: `scripts/ci-publish-ios.sh` is the checked-in preflight over the same
     `scripts/ship-ios.sh` release engine, not a second release implementation
   - deterministic listing screenshots: `scripts/screenshots.py` (iOS, simulator) or `scripts/mac_screenshots.py` (macOS, the real app on this machine)
4. Treat every action other than the two status scripts and screenshot dry runs as an external write. Confirm the exact platform, channel, version, tester group, and release intent from the user when any is ambiguous.
5. Preserve existing boundaries: `appstore_status.py` and `ci_health.py` remain read-only;
   `testflight_distribute.py` owns TestFlight metadata and groups; `appstore_listing.py` owns listing
   copy and build attachment; `appstore_screenshots.py` owns listing images; the sibling bot owns
   Resolution Center conversation. Never edit listing copy in the App Store Connect web form.
6. Never submit anything for App Review. No tool here does it and none should: it is a person pressing Submit.
7. For screenshots, use only the project-owned simulator names in `docs/guides/building.md`. A new
   simulator must launch the app once to register WidgetKit before capture; after that launch, the
   capture script re-seeds the fixture. Do not launch the app between seeding and capture.
8. Report the exact command, external effect, and any manual follow-up. Never claim store or TestFlight delivery from a green local build alone.

## Do not

- Do not introduce a second release engine or put credentials into the five verification jobs.
- Do not guess credentials, App Store Connect IDs, Xcode Cloud product IDs, build numbers, groups, or release channels.
- Do not treat the highest build number as the newest upload.

# Prepare 1.1.7 for the App Store

Prepare the iOS and macOS release records with the schedule timing improvements, current
listing copy and explicit uploaded builds. Stop before App Review submission.

**Status:** App Store drafts prepared and verified. Remaining: refresh the provisional
iOS build through TeamCity to include the widget middle-dot separator before submission.

## Scope and ownership

- App record: 6761343835, both IOS and MAC_OS, locale en-GB.
- Current project marketing version: 1.1.7. Live versions: iOS 1.1.6 build 10036,
  macOS 1.1.5 build 10032.
- `scripts/appstore_listing.py` owns metadata and build attachment. Its dry run previews
  writes and `--apply` prepares the version. No replacement release engine is needed.
- The sibling `apple-appstoreconnect-api` CLI uses its supplied browser capture for
  Resolution Center and App Privacy reads; official metadata writes use the existing
  app's App Manager key. No authentication contents are recorded here.
- Existing screenshots and review contacts are retained; no screenshot replacement,
  TestFlight group change, archive or review submission is in scope.

## Build provenance

- iOS 10068 and macOS 10069 are the newest uploaded and installable builds, both reserved
  from commit `9e78f61` by `scripts/submit_build.py`.
- They contain adaptive schedule names and local timings. iOS 10068 predates
  `d81b4b2`, the widget middle-dot separator. Attach it as a provisional selection and
  replace it with a newly uploaded iOS build before submission if that change is to ship.
- Uploads run through the person's manual TeamCity Ship action. Preparation does not
  authorize replacing that established release route.

## Acceptance and evidence

- [x] Read current App Store Connect status: no editable releases; live versions as above.
- [x] Read Resolution Center with the supplied capture: returned historical 1.1.2 thread.
- [x] App Privacy is published, DATA_NOT_COLLECTED, with no additional usage declarations.
- [x] Review platform-specific What's New for 1.1.7: independent spoiler-safety review,
  no substantive findings. `appstore_listing.py --selftest`: 15 cases, zero failures.
- [x] Create both release records, apply maintained listing copy and attach the explicit builds.
- [x] Read back metadata, build relationships, screenshots, contacts and release states.
- [ ] Replace iOS 10068 with a newly uploaded build containing the widget middle-dot separator.

## Remote result and commands

From the release worktree, ran these existing commands with `python3`:

```
scripts/appstore_listing.py --platform ios --version 1.1.7 --create --build 10068 --apply
scripts/appstore_listing.py --platform macos --version 1.1.7 --create --build 10069 --apply
```

Both succeeded. Repeating each without `--apply` or `--create` reported every managed
field already correct and the explicit build already attached. Root
`scripts/appstore_status.py --json` confirmed both versions remain
`PREPARE_FOR_SUBMISSION`, release type `AFTER_APPROVAL`, complete review contacts, no
demo account requirement, and no reported attention items. Inherited screenshots:
three iPhone, three iPad and two desktop. Screenshot counts were checked; their images
were not replaced or re-reviewed for this preparation.

Evidence is in root `tmp/logs/release-1.1.7-*-apply.log`,
`release-1.1.7-*-readback.log`, `release-status-after.json` and `release-privacy.json`.
No release was submitted or published. The retained task tracks the iOS build replacement;
the App Review Submit action remains manual.

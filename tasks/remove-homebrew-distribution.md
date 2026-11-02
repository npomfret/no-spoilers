# Remove Homebrew distribution

Status: preparation complete on 2 November 2026. Removal remains unexecuted. Only this task was
rewritten and renamed; the evidence files are ignored under `tmp/logs/`.

## Issue and authorized scope

On 2 November 2026 the owner asked to find all references to the Homebrew installation and prepare
to delete it all. This replaces the outstanding work to prove an independent Homebrew release.
Preparation is authorized; execution of removal is not yet requested.

The inventory covers No Spoilers' Homebrew installation, the Developer ID download channel that
supplies its cask, the macOS update banner, documentation, automation and the external tap.
Homebrew as a developer tool and the App Store/TestFlight delivery path are separate dependencies.

## Confirmed state

- Local checkout: `main`, initially clean. The separate `../homebrew-tap` checkout has an unrelated
  untracked `.DS_Store`; preserve it.
- The live cask is `npomfret/homebrew-tap`, `Casks/no-spoilers.rb`, version `1.1.4`, downloading
  `NoSpoilers-1.1.4.zip` from the No Spoilers GitHub release. Read again through the GitHub connector
  on 2 November 2026; the local cask agrees.
- The GitHub releases API returns 23 published releases, each with one No Spoilers zip asset.
  Latest: `v1.1.4`, published 9 September 2026, release ID `385739014`, asset ID `553292473`.
  Its asset has 24 downloads; this is not an installed-user count.
- The remote tap contains only `Casks/no-spoilers.rb`. Removing that cask does not require deleting
  the tap repository or its git history.
- `UpdateChecker` calls GitHub's latest-release endpoint and the macOS popover displays a copyable
  `brew upgrade` command. Its dependencies extend into the app root and menu bar label.
- `scripts/ci-publish.sh` has distinct Apple and Homebrew branches; removing the whole script would
  break `Ship iOS` and `Ship macOS`. Apple delivery and screenshots still call `_version.sh`.
- Live TeamCity settings contain six configurations: `ShipIos`, `ShipMacos`, `Verify`,
  `VerifyPython`, `VerifySwiftTests`, `VerifyXcode`. No Homebrew configuration or Homebrew/cask
  reference was found in that project's settings. There is no Homebrew CI job to delete.

## File inventory and proposed treatment

Locations below are from the source before removal. Literal Homebrew/brew/cask matches occur in
19 project files, excluding this task. The broader dependency search finds 256 matching lines in
27 files; the website stylesheet, brand guide and installation image add three indirect files.
Exact matching lines are in `tmp/logs/homebrew-reference-audit.txt`.

| File / starting line | Proposed treatment |
| --- | --- |
| `scripts/ship-homebrew.sh:1` | Delete the Homebrew wrapper. |
| `scripts/release.sh:1` | Delete the Developer ID archive/export/notarize/staple/GitHub-release/cask engine. Its current delivery caller is the Homebrew branch of `ci-publish.sh`. |
| `NoSpoilers/ExportOptions-DeveloperID.plist:1` | Delete; its only source caller is `release.sh`. |
| `scripts/ci-publish.sh:15` | Remove the `homebrew` platform, channel-only constants and prerequisites, tap clone and final wrapper invocation. Keep iOS/macOS signing, both App Store Connect keys, tag push checks, `--check` and the early `--apply` refusal. |
| `NoSpoilers/NoSpoilersMac/UpdateChecker.swift:1` | Delete the GitHub latest-release client, receipt detection and version comparison. |
| `NoSpoilers/NoSpoilersMac/ContentView.swift:30` | Remove both injected checker properties, update banner, `brewCopied` state, clipboard action and confirmation callback. Preserve schedule refresh and other popover screens. |
| `NoSpoilers/NoSpoilersMac/NoSpoilersMacApp.swift:13` | Remove checker construction/injection, menu bar update dot, launch check at 141 and wake check at 212. Preserve both schedule refreshes. |
| `NoSpoilers/NoSpoilersMac/Strings.swift:13` | Remove `updateAvailable`, `brewUpgradeCommand`, `copyCommand`, `copied`; all belong to this banner. |
| `NoSpoilersCore/Sources/NoSpoilersCore/Theme.swift:132` | Banner-only symbols: `Palette.confirmation`, `Motion.confirm`, `Motion.confirmationHold`, `Icon.updateAvailable` (1062). Remove their declarations and corresponding comments with their only consumer. |
| `NoSpoilersCore/Sources/NoSpoilersCore/AppLog.swift:89` | Remove the `update` channel and its explanation (113–122); rewrite the alerts comment that refers to it. All channel writes are in `UpdateChecker`. Load the auditing skill before editing. |
| `NoSpoilersCore/Sources/NoSpoilersCore/HTTPSession.swift:6` | Remove obsolete checker/latest-release/`api.github.com` commentary. Keep the session and its existing timeout policy: schedule and session-status requests still use it. |
| `NoSpoilersCore/Sources/NoSpoilersCore/AppVersion.swift:9` | Update obsolete banner and current build-writer commentary. Keep the version accessors and their missing-data failure. |
| `README.md:128` | Remove install/upgrade instructions, the second delivery path at 145/180, notarization setup and Homebrew-specific credential requirements. Keep the App Store listing and Apple delivery instructions/credentials. |
| `docs/index.html:298` | Remove Homebrew install/update/uninstall blocks and links, divider, related Applications-folder instructions/image, copy functions at 423–456 and their now-unused CSS selectors, including the responsive command rule. Keep the existing App Store link and trademark disclaimer. |
| `docs/applications-folder.png` | Delete after removing its sole reference in the Homebrew installation block. |
| `docs/styles.css:46` | The command/copy block alone uses `--on-dark`, `--on-dark-quiet`, `--on-dark-strong`, `--success-bright`, `--mono`; remove these with it. Keep shared palette entries such as `--success-green`. |
| `docs/guides/brand.md:124` | Remove the `Palette.confirmation` role row if that banner-only symbol is removed. Preserve the other shared design roles. |
| `docs/guides/building.md:103` | Remove current Homebrew delivery, preflight and credential instructions; revise tag/channel descriptions. It also contains historical releases/signing evidence: distinguish that from active instructions. |
| `docs/guides/important-code.md:26` | Remove ownership entries for deleted scripts and update entry 39 (`ci-publish.sh`), the version helper and approval-tag explanations. Preserve owners of Apple tooling. |
| `.claude/skills/release-and-delivery/SKILL.md:29` | Remove the Homebrew release route and update the current bare-version-tag policy at 34. Preserve Apple delivery/write boundaries. |
| `.codex/rules/project.rules:60` | Remove only `release.sh` and `ship-homebrew.sh` from the publishing-script rule. Preserve the rule for the surviving Apple writers. |
| `.teamcity/settings.kts:239` | Remove the comment advertising `--platform homebrew`; leave the two Apple delivery configurations intact. |
| `scripts/_version.sh:23` | Keep the helper and tag/build-number handling; remove current Homebrew-channel instructions and correct attribution to the surviving Apple writer. Historical bare tags remain valid input. |
| `scripts/open-version.sh:15` | Retain the script; its `release.sh` reference explains the old version-rewrite defect. No runtime call to the deleted engine exists. |
| `scripts/tag_approved.py:5` | Retain approval tagging. Remove the active cask/bare-tag instruction at 20–21; the other legacy-release references explain historical approval provenance. |
| `scripts/submit_build.py:7` | Retain Apple delivery and its rsync/PATH protection. Homebrew's rsync is a developer-tool conflict, not this distribution channel. The `release.sh` mentions are historical. |
| `scripts/testflight_distribute.py:22` | Retain legacy `build/N` and bump-commit lookup, validation and selftests. Its `release.sh` references describe actual older Apple uploads; they are not calls to the deleted script. |
| `scripts/appstore_status.py:584` | Retain historical build-number-band handling and its explanatory references at 736/1743. |
| `docs/apple-release-comparison-2026-09-10.md:3` | Dated historical audit, including actual failed-build evidence and old Homebrew-separation recommendations. It is not a release entry point. See history decision below. |
| `AGENTS.md:74` | Retain the generic `brew install shfmt` example. This generated standards text is about developer tooling, not installing No Spoilers. |

The Xcode project uses synchronized source groups; there is no explicit `UpdateChecker.swift`
file entry to remove from `project.pbxproj`.

## Other matches and external targets

- `../homebrew-tap/Casks/no-spoilers.rb`: remove the cask in that repository when removal is
  authorized. The live file is
  `https://github.com/npomfret/homebrew-tap/blob/main/Casks/no-spoilers.rb`.
- Published downloads: `https://github.com/npomfret/no-spoilers/releases`. The exact 23 release IDs,
  asset IDs, tag names and download URLs are recorded in
  `tmp/logs/homebrew-github-release-inventory.json`. Tags are `v1.0.0`–`v1.0.9`,
  `v1.0.12`–`v1.0.22`, `v1.1.1`, `v1.1.4`; each has `NoSpoilers-<version>.zip`.
- The ignored `.idea/workspace.xml` and 15 files under the ignored third-party
  `research/example-project/` also contain literal matches. They are local IDE state and a
  CodexBar research checkout, not No Spoilers distribution. Their locations, alongside project
  matches, are in `tmp/logs/homebrew-all-reference-locations.txt` (189 matching lines). Leave them
  outside the product deletion. Generated build caches, `.git`, `node_modules`, `DerivedData`,
  `.gitnexus`, Python bytecode and `tmp` were excluded from that search.
- The source advertises the GitHub Pages site at `https://npomfret.github.io/no-spoilers/`.
  Its checked-in landing page was audited; deployed Pages content was not independently fetched.
- `no-spoilers-notarytool` is the channel's named keychain profile. Its actual presence was not
  inspected. Do not revoke certificates or delete either shared App Store Connect API key as part
  of removing this channel; both keys remain in the Apple delivery path.

## Decisions before deletion

1. Confirm retirement of the complete Developer ID download channel together with Homebrew.
   The current cask and GitHub updater are supplied by that same channel; keeping direct downloads
   would require a different agreed update policy, outside this removal plan.
2. Choose whether the 23 already-published GitHub releases/assets are retained as history or
   deleted too. Cask retirement alone does not remove direct download links. Existing installed
   copies continue running and retain their old GitHub updater; changing source does not migrate
   them. Deleting every release leaves that updater without a latest release to fetch.
3. Choose whether factual historical references in the dated audit and build-provenance comments
   remain, clearly identified as history. Removing current installation instructions does not
   require erasing that evidence. Preserve `build/*`, `ios/v*` and `macos/v*`; deletion of historical
   bare `v*` tags or either whole repository is not implied by cask removal.

## Execution plan after the scope is confirmed

- [ ] Make the local deletions and edits listed above in one coherent change, keeping App Store
  installation and Apple publishing operational. Do not run a release to validate removal.
- [ ] Re-run the source/reference searches. No current install command, Homebrew platform option,
  GitHub update request or caller of a deleted file should remain. Classify any retained historical
  or developer-tool match explicitly.
- [ ] Verify serially: `scripts/verify-core-tests.sh`, `scripts/verify-python-selftests.sh`,
  `scripts/verify-mac-build.sh`, `scripts/verify-ios-build.sh`, `scripts/verify-widget-build.sh`.
  Confirm no controlled test process is active before starting; each runner must use one worker.
  Preserve existing limits. Inspect the landing page at desktop and mobile widths.
- [ ] Preserve the existing `submit_build.py` selftest proving that `ci-publish.sh --apply` and
  `--check --apply` are refused before preflight. No dedicated updater/banner tests were found;
  the nearby HTTP, version and log tests exercise shared behavior that must survive.
- [ ] Have the significant implementation reviewed by an agent before committing; answer all real
  findings. This preparation changes only a task file and requires no implementation review.
- [ ] Immediately before an authorized external removal, re-read the owning automation, remote
  cask and exact release/asset IDs. Apply only the confirmed external deletions; verify the cask is
  absent and the agreed release disposition matches remote state. No local package-manager
  uninstall or user-data deletion is part of retiring distribution.

## Preparation verification

- Completed the literal and broader dependency searches, checked both macOS callers and shared
  HTTP/version/log/theme owners, checked the Xcode source groups and nearby tests, and read the
  publishing wrappers without running them.
- Read the live cask, tap directory and complete releases collection through the GitHub connector.
  No remote write was made.
- Executed `python3 scripts/teamcity.py settings --json` successfully. Evidence:
  `tmp/logs/homebrew-teamcity-settings.json`; stderr is empty. No build was started.
- `git diff --check` passed. The new task's `git diff --no-index --check` emitted no whitespace
  errors (exit 1 denotes the new-file difference). All 30 inventory paths exist, and the saved
  release inventory parses as 23 records. Working-tree inspection shows only the old task path
  removed and its replacement untracked; neither repository has had distribution files edited.
- Preparation does not change product code, scripts, configuration, website or external state.
  No tests or builds were run for this task-file-only change.

Apple release comparison — 10 September 2026

The recommended solution is to make No Spoilers follow Funmax's existing TeamCity → verified commit → signed upload → processing wait → internal TestFlight delivery pattern. Keep Homebrew independent. Retain No Spoilers' platform-specific listing and approval tools, because Funmax does not currently automate a public App Store release.

Confirmed scope: automation ends at TestFlight. The final App Review submission button remains manual. Reusable findings are also recorded in [agent-standards/docs/apple-testflight-delivery.md](../../agent-standards/docs/apple-testflight-delivery.md).

Homebrew is a completely separate flow, with its own trigger, prerequisites and release cadence. Neither flow depends on the other's success, and their version/build numbers need not remain synchronised. Shared source and helper code do not require a combined release orchestrator.

This was a read-only investigation of source, live TeamCity configuration and logs, App Store Connect records, local LaunchAgent configuration, and installed provisioning-profile metadata. No release, Apple account change, CI configuration change, or source-code change was made. Offline release-tool selftests were run. Audit outputs are downloaded logs, this report, and the requested reusable documentation in agent-standards.

Source snapshots: No Spoilers `be9b9873`, Funmax `a9c82aa9`, and the updated shared TeamCity documentation at `e845bec0`. Live reads were made on 10 September 2026, around 09:00 UTC. The latest observed No Spoilers signing preflight was on 9 September; it is evidence from that agent session, not a new signing test today.

Before committing this report, No Spoilers was updated to `95fdae2`. Incoming commit `0c0db91` implements the temporary Homebrew tap clone; `9edcccd` refreshes the tap before cask updates. The sibling-checkout defect described in the original audit is therefore fixed in current source. Historical failed-build evidence remains accurate. Homebrew is still part of the combined Apple release path and must be separated.

**What is proven to work**

| Evidence | Observation | What it establishes |
|---|---|---|
| [Funmax Ship #61](https://ci.snowmonkey.co.uk/buildConfiguration/SuperFunMaxMusic_Ship/3130) | On 5 September, `macstudio-2` archived commit `83b10631f9a8` as 1.3 (138), uploaded it, waited 2.4 minutes for processing, wrote the tester note and confirmed Kitchen had the build. Whole job: about five minutes. | A complete unattended TestFlight delivery from a TeamCity checkout. Seven recent Ship jobs inspected were successful. |
| [No Spoilers Ship #4](https://ci.snowmonkey.co.uk/buildConfiguration/NoSpoilers_Ship/4202) | On 9 September, `macstudio-3` ran `ci-publish.sh --platform all --check`. Apple Distribution signing passed. Three prerequisites failed: Mac Installer Distribution identity, Developer ID Application identity, and sibling Homebrew tap checkout. | The latest new Ship configuration is blocked in preflight. All four executions of this configuration failed; none reached an archive. |
| [No Spoilers TestFlight #3](https://ci.snowmonkey.co.uk/buildConfiguration/NoSpoilers_TestFlight/4148) | The separate distribution job successfully handled both platforms and found build 10024 already assigned to Internal. | The agent can authenticate to the distribution API and run the existing distribution workflow. This job does not build or upload. |
| Live No Spoilers App Store Connect | macOS 1.1.3, build 104, and iOS 1.1.3, build 112, are `READY_FOR_SALE`. Both platforms' newest uploaded and installable TestFlight build is 10024. | Existing Apple delivery works independently of the new Ship job. Build 10024 was not produced by that job. |
| Live Funmax App Store Connect | Public version 1.0 is `PREPARE_FOR_SUBMISSION`, with build 73 attached and no submission history returned. | Funmax is the reference for TestFlight automation, not a demonstrated public App Store submission pipeline. |

Funmax's current verification is red: [Checks #233](https://ci.snowmonkey.co.uk/buildConfiguration/SuperFunMaxMusic_Checks/4227) fails because the shared TeamCity CLI is not installed where its selftest shim searches. Its latest successful Ship remains #61. The delivery gate is correctly withholding a newer release. This does not require redesigning Funmax's release flow, and no Funmax changes were made.

**How Funmax works**

The authoritative chain is [.teamcity/settings.kts](../../super-funmax-music/.teamcity/settings.kts). Relevant pushes trigger Compile and Checks, then Unit and three UI configurations run under a composite Verdict. Compile checks both Debug and Release. Unit/UI results are published as JUnit and retained with logs. Successful Verdict completion triggers Ship with a snapshot dependency on the same revision. A nightly runs the same chain and also ships when green.

Ship invokes [submit_build.py](../../super-funmax-music/apple/scripts/submit_build.py) with `--apply --tested`. The script:

1. Refuses a dirty checkout and conflicting Xcode activity.
2. Reads the actual Release settings for version, team and app identity.
3. Allocates a build number from App Store Connect, one above the highest for that marketing version, counting expired builds.
4. Archives the device Release build with `CURRENT_PROJECT_VERSION=N` on the command line. It does not edit the project, commit, rebase or push the branch.
5. Uses `xcodebuild -exportArchive` with `method=app-store-connect`, `destination=upload`, automatic signing, symbols enabled, and `manageAppVersionAndBuildNumber=false`.
6. Polls the specific uploaded version/build until Apple reports it ready, with a one-hour ceiling and progress output.
7. Calls [testflight_distribute.py](../../super-funmax-music/apple/scripts/testflight_distribute.py) to write the commit-based note and ensure internal-group membership.

The same entry point is available locally through `npm run testflight:ship -- --apply`; without `--tested`, it runs its own unit-test gate. The app also embeds its commit identity. The Apple tools get `/usr/bin` first on PATH to avoid the documented Homebrew rsync/export conflict.

The project uses Python and Apple's CLI tools; it has no fastlane dependency. There is no benefit to introducing a new language or release framework merely to align No Spoilers with it.

**Why signing works on this Mac**

The [updated agent documentation](../../snowmonkey-proxy-common/docs/TEAMCITY-AGENTS.md) and local LaunchAgent files agree: all three agents run as `nickpomfret`, but each has its own checkout and temporary directories. The signing keychain and API-key files belong to the user, so those are shared across the three agents.

Being signed into an Apple account helps establish the session, but it is not the complete release credential. Funmax uses a locally installed Apple Distribution identity with its private key, a matching App Store provisioning profile, and App Store Connect API keys. TeamCity supplies issuer/key identifiers as password parameters; the `.p8` private keys are files in `~/.appstoreconnect/private_keys`. The Developer key is used for reporting; the App Manager key is used for uploading/distribution. The variable name `ASC_ADMIN_KEY_ID` should not be read as proof that its role is Admin.

Apple explicitly supports local distribution signing with a certificate installed in the keychain; cloud-managed signing is a separate credential path. [Apple: cloud-managed certificates](https://developer.apple.com/help/account/certificates/cloud-managed-certificates/).

Installed profile metadata was decoded locally. The following App Store profiles all permit distribution (`get-task-allow=false`), expire on 21 August 2027, and include the Apple Distribution certificate fingerprint reported by the successful agent signing probe:

| Profile target | Required app group |
|---|---|
| `pomocorp.FunMaxMusic` | None |
| `pomocorp.NoSpoilers.NoSpoilersMac` — iOS app | `group.pomocorp.no-spoilers` |
| `pomocorp.NoSpoilers.NoSpoilersMac.NoSpoilersWidget` — extension | `group.pomocorp.no-spoilers` |

No matching macOS distribution profile was found in the inspected Xcode provisioning-profile directory. That alone does not establish what automatic export can generate, so macOS archive/export remains to be proven. The missing Mac Installer Distribution identity is independently confirmed by the last real agent preflight. A valid installer certificate must include its private key; simply installing a `.cer` is insufficient.

The sandboxed shell reported zero usable identities, despite the build log proving the agent signed successfully. That shell result was not used to diagnose the agent. Signing must be tested in the agent's session; installer signing should ultimately be tested with an exported package, not just a presence check.

**Where No Spoilers differs**

| Area | Funmax | No Spoilers today | Recommended alignment |
|---|---|---|---|
| Release trigger | Successful Verdict automatically starts Ship | Manual Ship; manual TestFlight | Successful Verify starts Apple Ship; retain a retry/manual entry point |
| Outcome of Ship | Uploaded, processed, note written, internal distribution confirmed | Upload only; console tells someone to distribute later | Make all four operations one job outcome |
| Channels | iOS App Store Connect | Mac App Store → Homebrew → iOS App Store | Apple iOS/macOS jobs independent of Homebrew |
| Source revision | Tested checkout stays unchanged | May commit a version change and pull/rebase before archiving | Archive the exact verified revision |
| Version | Marketing version committed beforehand | Release can choose and commit next patch version | Open the next marketing version before verification |
| Build number | Command-line override; no source edit | Command-line override plus global `build/N` ledger | Retain the useful ledger and allocate once per coordinated Apple run |
| Export/upload | Modern direct Xcode upload | Local export, then `altool` validation/upload | Use the same explicit Xcode export options and upload pattern |
| Verification | Debug/Release, unit/UI, true composite, test records | Unsigned Debug app builds, SwiftPM tests, script selftests; ordinary empty Verify job | True composite; Release compile coverage; publish test results |
| Public store release | Not automated | Listing/screenshot tools and approval tags; submission still manual | Preserve those tools and promote a chosen uploaded build separately |

The relevant No Spoilers sources are [settings.kts](../.teamcity/settings.kts), [ci-publish.sh](../scripts/ci-publish.sh), [ship.sh](../scripts/ship.sh), [release.sh](../scripts/release.sh), and [_version.sh](../scripts/_version.sh).

**Changes that matter most**

1. **Remove Homebrew from the Apple dependency chain.** The current `all` preflight refuses an iOS upload because Homebrew credentials or a tap checkout are missing. Later, a Homebrew failure after the macOS upload prevents the iOS invocation from starting. Separating the channel removes both failures without provisioning anything Homebrew-specific. Developer ID, notarization, GitHub releases and the cask belong exclusively to that channel.

2. **Supply the macOS installer signing identity and prove export.** The existing Apple Distribution identity and iOS app/widget profiles can be reused. Install the missing Mac Installer Distribution identity once for `nickpomfret`, confirm any macOS profile requirements during export, and exercise signing from each eligible agent. No new agent or Apple account is required.

3. **Keep the verified source immutable.** `release.sh` runs its core-test gate at line 362, changes/commits the marketing version at line 429, and can pull/rebase at line 467 before archiving. A rebase can introduce source that neither that gate nor the upstream TeamCity verification tested. Moving a marketing-version change into a prior commit and refusing revision movement during Ship fixes this. A stale queued revision can still be shipped faithfully, or deliberately refused and requeued; it should not silently become a different revision.

4. **Automate processing and distribution for the exact build.** Keep No Spoilers' existing per-platform API filtering, tester notes, and `--build N` option. The Apple ship step should wait for each uploaded build and pass its exact identity to distribution, then read back membership. This also makes retrying delivery possible without rebuilding. Public App Review is a separate promotion of the chosen build.

5. **Use explicit export settings and durable release evidence.** No Spoilers' current export plist uses deprecated `app-store` and omits `manageAppVersionAndBuildNumber`. Local `xcodebuild -help` confirms the supported replacement is `app-store-connect` and automatic build-number management defaults to YES. This is not a demonstrated cause of the current failures: today's pipeline exports locally and uploads via altool. When aligning to Funmax's direct upload, explicitly disable renumbering and verify the exported/uploaded number, not only the archive. Keep a TeamCity artifact containing commit, version, platform, build number, ASC build ID and delivery result, plus useful export diagnostics.

6. **Align the verification and operational surface.** Turn Verify into a real composite, add Release compilation to the app checks, and retain the existing unsigned-build isolation. Do not propagate the verification scripts' temporary HOME into signing. Include Ship/TestFlight in status output: No Spoilers' `.teamcity/cli.json` currently whitelists only verification, so its normal status command omits the release failures. Use the same environment variable names and command conventions as Funmax. The existing shared CLI shim needs the plugin installed or `TEAMCITY_CLI` set; the audit used the local `agent-standards` implementation directly.

Two details should be improved while porting the pattern rather than copied blindly. Funmax waits for an exact build but its distributor subsequently chooses the newest; explicit build selection is safer and No Spoilers already supports it. No Spoilers' build-history readers currently take one page of 200, while Funmax's build-number calculation paginates the build collection. Automated uploads make complete pagination necessary. Neither is the observed signing blocker.

The Xcode locks also have different project-local names. They do not coordinate the two projects. Funmax's ship script refuses to start while any other xcodebuild is running, so simply increasing No Spoilers automation can produce avoidable refusals. Agree a shared machine resource for mutually exclusive archive/compile operations, or demonstrate that isolated build directories permit the intended concurrency. This requires an estate-level decision; it is not a reason to provision another agent.

**What to preserve**

No Spoilers' macOS and iOS builds share one app record under Universal Purchase, but have separate platform versions, reviews and approved builds. Its two iOS profiles and App Group entitlement must be preserved. Its global monotonically increasing build numbers and `build/N` tags are useful existing provenance; there is no need to reset them to Funmax's smaller numbers. Preserve `ios/vX.Y.Z` and `macos/vX.Y.Z` as approval records, and keep the bare `vX.Y.Z` tag for Homebrew. Preserve the listing text, screenshot tooling and read-only App Store status report.

Opening the next marketing version should be an explicit source change before the verification chain. The current automatic `all` decision refuses when macOS and iOS disagree about which version can accept another build. Treat those independent Apple review states explicitly instead of restoring Homebrew coupling to keep every channel numerically identical. A coordinated Apple release can still allocate one common build number while reporting each platform's result separately.

For cadence, match Funmax's successful-verification trigger. Its nightly also uploads unchanged commits; document whether No Spoilers should inherit that exact behaviour or skip an already-delivered commit. This choice is separate from whether a successful Apple Ship includes actual TestFlight delivery.

**Updated documentation discrepancy**

The shared TeamCity docs were reread after the update at `e845bec0`. Their new signing and user-directory explanations agree with the live evidence. Their claim that No Spoilers clones the tap into the build's temporary directory initially disagreed with local revision `be9b9873`. Fetching before commit resolved the discrepancy: `0c0db91` already implements the clone, and it is now in the local checkout at `95fdae2`. Preserve that implementation for the independent Homebrew flow; no hand-placed sibling checkout is needed. The revised clone path was inspected, not executed by this audit.

Several project documents retain historical Xcode Cloud instructions and stale assertions alongside corrections. The current Kotlin configuration, executable scripts and live build logs were treated as authoritative where prose disagreed. Current repo documentation records Xcode Cloud disabled/retired; the historical cloud hooks are not the migration template.

**Implementation and acceptance sequence**

1. Refactor No Spoilers around Funmax's immutable Apple delivery flow; remove Homebrew prerequisites from it and preserve the working platform-specific API helpers.
2. Configure the common API environment names, installer identity and any necessary macOS provisioning assets. Keep private keys in the existing user-owned location.
3. Run a signing preflight on each eligible agent, then signed archive/export checks for both platforms without uploading. Inspect app/widget versions, entitlements, profile/certificate matches and the macOS package signature.
4. For the first real delivery, demonstrate one verified SHA through upload, Apple processing, correct tester note and confirmed Internal membership on each platform.
5. Demonstrate that a failed verification blocks shipping, a Homebrew failure cannot affect Apple delivery, and a failed processing/distribution stage can resume against its recorded build without another upload.
6. Enable the successful-verification trigger and keep public App Store submission as a separate operation using the already uploaded build.

The offline checks run during this audit passed: No Spoilers' five Python selftest suites (196 cases total), Funmax's submit_build selftest, and Funmax's testflight_distribute selftest. No fresh archive, export, upload or device installation was attempted, so those acceptance steps remain work for implementation.

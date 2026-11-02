# TestFlight delivery follow-ups

Status: complete, 2 November 2026. The three follow-ups are checked, the documentation review
is clean, and the owner approved committing and retiring the task. Shared delivery guidance is
committed as `agent-standards` `cca18d9`; Funmax's guide is committed as `d4b8899a`. This commit
lands the No Spoilers guidance and final evidence; task deletion follows in a separate commit.

- [x] Confirm `~/Desktop/certs.p12`, which held two signing private keys, is gone from the
  Mac Studio. A metadata-only SSH check on 2 November 2026 returned "No such file or directory"
  for `/Users/nickpomfret/Desktop/certs.p12`. No key material was read or changed. Evidence:
  `tmp/logs/testflight-followups-certificate-presence.log`.
- [x] Recheck the old profile-count/churn concern and establish whether pruning is justified.
  The relationship API returned 293 app rows and 214 widget rows, with repeated IDs (289 and 202
  distinct IDs observed in that read). Every returned row is ACTIVE and unexpired, but creation
  dates are null; these raw counts cannot establish a change from September's 292.
  The normal, ID-sorted profile collection did not return the managed names; one direct managed
  profile read per type returned 404. The named `No Spoilers Mac App Store` profile is directly
  readable, ACTIVE, created 2026-09-10 and expires 2027-08-21. Apple's documentation explains that
  Xcode-managed profiles do not appear in the developer account, and Xcode generates a profile
  when its cache has none that meets the signing requirements. No safe stale deletion target or
  current quota incident was established, so no profile or identity was deleted. Durable
  conclusions are in `docs/guides/building.md`; evidence is under
  `tmp/logs/testflight-followups-profile-*` and `testflight-followups-bundle-identifiers.json`.
- [x] Add all four lessons to `agent-standards/docs/apple-testflight-delivery.md` and
  Funmax's `apple/docs/builds-and-delivery.md`: the outer timeout must cover the actual phase
  budgets and reporting; Xcode's log bundle is in `getconf DARWIN_USER_TEMP_DIR` despite `TMPDIR`;
  directory artifacts need `/**`; imported private keys need the Apple-tool partition list in
  addition to trusted applications. Funmax currently does not retain the distribution bundle in
  TeamCity artifacts, and its 90-minute job limit is below 145 minutes of allowed phases before
  other work; both limitations are stated explicitly. This follow-up adds the requested lessons,
  not a new retention implementation or changed timeout. No release or CI mutation was performed.

## Verification and completion

The source and live TeamCity settings agree that Funmax's `Ship iOS` and `Ship Mac` limits are
90 minutes.
No Spoilers keeps its existing 210-minute outer limit and defined script budget. Live settings
were read only through each project's `scripts/teamcity.py`; no build was started. Evidence:
`tmp/logs/testflight-followups-funmax-ship-settings.json` and
`testflight-followups-funmax-ship-mac-settings.json`, plus
`testflight-followups-no-spoilers-settings.json`.

- [x] Review the documentation diff against the source, official profile documentation and current
  read-only observations; run whitespace/link checks and answer all real review findings.
  The agent inspected all three patches and underlying evidence and found no real issues.
  `git diff --check` passed in each repository for the changed files; the Apple documentation link
  was opened successfully. No tests or builds were needed or run for these documentation changes.
No required investigation or documentation work remains. Funmax's existing timeout and artifact
retention limitations are recorded explicitly; changing those behaviors was outside this task's
request to transfer the lessons. No signing assets, provisioning profiles or CI settings changed.

Unrelated work preserved: `agent-standards/plugins/teamcity/scripts/teamcity.py` was already
modified, and Funmax's `apple/tasks/make-builds-clean-up-their-disk-usage.md` was already deleted.

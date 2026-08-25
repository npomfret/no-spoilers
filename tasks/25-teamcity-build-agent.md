# Task 25: put the build on TeamCity

**Status: PHASE 1 DONE, 2026-08-25.** Four configurations exist on
`ci.snowmonkey.co.uk`, they went green on `main`, and they have been shown to go red.
Phase 2 (the release path) is written down below so its cost is visible, and is **not**
recommended.

Reference: `/Users/nickpomfret/projects/snowmonkey-proxy-common/docs/TEAMCITY-AGENTS.md`, which is
the server owner's document and was verified against the running server on 2026-08-23. Everything
about the *server* below is quoted from it or read out of its REST API; everything about *this
repo* was read out of this repo.

## Why, and the history it had to answer

**This is the third attempt at CI for this project**, and the first two are the reason to be
careful rather than a reason not to try.

- `.github/workflows/release.yml` was deleted on 2026-08-12 **having never once succeeded**
  (`docs/guides/important-code.md` §20).
- **Xcode Cloud has no compute quota left**, confirmed 2026-08-22: runs 33, 34 and 35 were all
  cancelled 5-8 seconds after creation and `POST /v1/ciBuildRuns` answers `500`
  (`tasks/23-native-functionality-for-4-2-2.md`). Every build since has been a local
  `scripts/release.sh` run.

So the value on offer is not "automate the release" — that has been tried twice and the release
path is currently the one thing that *does* work. It is **"stop finding out at ship time that a
target does not compile."** The five verification wrappers already existed, already ran offline,
and nobody ran all five before every commit.

## What the agents turned out to be

Answered 2026-08-25 by reading `/app/rest/agents` over the tunnel. The two gates this task said
had to be settled before anything else — *which Mac* and *is a licence slot free* — were both
already closed:

- `funmax-mac-1`, `funmax-mac-2`, `funmax-mac-3`, all connected and authorized. **All three are
  one machine**: `macstudio.local`, 12 cores, 32 GB, agent work dirs under
  `/Users/nickpomfret/teamcity-agent*/work`. Not Nick's daily laptop, so CI compiles do not fight
  interactive work — but see the lock note below, because one machine is still one machine.
- **Xcode 26.6.0 / iOS 26.5 SDK**, identical to the development laptop, plus `/usr/bin/python3`
  and git 2.50.1. Everything Phase 1 needs was already installed; §7's "the server installs
  nothing on your agent" cost us nothing.
- Three agents is the whole free-tier licence, so **this project takes no slot of its own** — it
  shares the three that already existed.

## The VCS root needs no credential

`api.github.com/repos/npomfret/no-spoilers` answers `200` unauthenticated: the repository is
public. So the VCS root authenticates as `ANONYMOUS` and Phase 1 is genuinely secret-free — no
signing identity, no App Store Connect key, no push rights, nothing on the agent to steal.

There *is* a `NpomfretTeamCity` GitHub App connection on the root project, which would buy commit
statuses back on GitHub. It is deliberately not used yet: it is a credential, and the point of
Phase 1 was to need none.

## The shape, and where it came from

`SuperFunMaxMusic` had already solved this on the same server, so its structure was copied rather
than reinvented: an aggregating `Verdict` that runs nothing, a shared-resource write lock around
anything that starts Xcode, `env.TMPDIR` redirected into the build temp dir, and allowlist trigger
rules that exclude prose directories.

| Configuration | Runs | Xcode lock |
|---|---|---|
| `NoSpoilers_Checks` | `scripts/verify-python-selftests.sh` | none — starts no Xcode |
| `NoSpoilers_Build` | `verify-mac-build.sh`, `verify-ios-build.sh`, `verify-widget-build.sh` as three steps | `no-spoilers-xcode` readLock |
| `NoSpoilers_Tests` | `scripts/verify-core-tests.sh` | `no-spoilers-xcode` readLock |
| `NoSpoilers_Verdict` | nothing; snapshot-depends on the other three | — |

`Build` and `Tests` held **write** locks until 2026-08-25, which on a quota-3 resource means
"drain the machine" and made our own two configurations queue behind each other on a machine with
three agents. Nothing about them needs that: they are hermetic compiles in separate checkouts with
`HOME`, the caches and DerivedData redirected inside each one, and neither boots a simulator. The
resource is kept rather than deleted because it is what a future simulator-driving configuration
would take a write lock on — and a write lock only means anything if what it has to displace is
holding read locks.

Two deliberate departures from the pattern it was copied from, both because the underlying reason
does not carry over:

- **`Tests` is not downstream of `Build`.** Their `Unit` depends on their `Compile` because the
  tests consume its output. `verify-core-tests.sh` is SwiftPM and builds its own sources, so
  making it wait would let a broken Xcode target hide a test result it cannot actually affect.
- **The three Xcode wrappers are one configuration, not three.** They queue behind the same write
  lock whatever happens, so splitting them would buy three checkouts and no parallelism.

Trigger rules are `+:NoSpoilers/**`, `+:NoSpoilersCore/**`, `+:scripts/**` on the default branch.
`tasks/`, `docs/`, `listing/` and `.claude/` are prose: a commit touching only those cannot change
a compile result, and triggering on them trains people to ignore the light.

## Evidence

Local baseline first, because a red first CI run has to mean the agent and not the code — all five
wrappers passed on `main` before anything was created (`scratchpad/phase1-local.log`, exit 0).

Then, on the server:

```
#455 NoSpoilers_Checks   SUCCESS  0m11s  on funmax-mac-1
#456 NoSpoilers_Build    SUCCESS  1m01s  on funmax-mac-1
#457 NoSpoilers_Tests    SUCCESS  0m31s  on funmax-mac-1
#458 NoSpoilers_Verdict  SUCCESS  0m11s  on funmax-mac-1
```

`Build`'s minute is real and not a no-op: its log carries 345 Swift compile tasks, a full package
resolution and three separate `BUILD SUCCEEDED` (mac 22s, ios 18s, widget 9s). The Mac Studio is
simply quicker than the laptop.

**And it goes red.** A configuration that has only ever been green is indistinguishable from one
that reports success unconditionally, so a throwaway config whose only step was `exit 1` was hung
off `Verdict`, run, and removed:

```
#463 NoSpoilers_Verdict  FAILURE  Snapshot dependency failed: ... Red test
Verdict now depends on: ['NoSpoilers_Build', 'NoSpoilers_Checks', 'NoSpoilers_Tests']
```

The three real configurations were never edited during that, so a crash midway would have left an
unused extra config rather than a broken real one. Cleanup is verified in the same run.

The open question this task raised — whether `verify-core-tests.sh` and the Python selftests
survive the redirected `HOME` on a machine that is not a developer's — is now answered by #455 and
#457 passing on a fresh agent-side checkout.

## Known, and deliberately not fixed here

**`funmax-xcode` is defined inside the `SuperFunMaxMusic` project, so our builds cannot see it and
theirs cannot see ours.** Two projects' Xcode builds can therefore run at the same moment on the
one Mac Studio.

This task first recommended moving that lock to the root project so the estate shared one. **That
recommendation was wrong and was withdrawn on 2026-08-25 after reading what the locks actually
do.** The quota is 3, which is the agent count, so `readLock` (1 of 3) means "I am using Xcode but
tolerate company" and `writeLock` (all 3) means "drain the machine". Their UI legs hold read locks
and run three-up; `Compile`, `Unit` and `Ship` hold write locks.

Joining that pool would make our **one-minute** chain drain their **fifteen-minute** UI matrix
before it could start, and hold the whole machine while it ran — slower for both projects, to fix
contention that is not causing failures. And moving the definition means deleting it from their
project and recreating it at root while their configurations still name it, so a surprise in name
resolution breaks somebody's `Ship`. Not worth it for a performance nicety.

What is true is narrower: `SuperFunMaxMusic_Ship` takes a write lock, which is a release declaring
it needs a quiet machine, and today that is quietly false because our compiles can run underneath
it. The cost is CPU contention during a notarize, not a broken build. **Revisit the moment
anything here boots a simulator** — `screenshots.py` or `alerts_check.py` reaching CI would make
two projects drive `simctl` on one machine, which is exactly the failure `CLAUDE.md` warns about
for the stock simulators, and then joining the estate lock with a *read* lock becomes correct.

`SuperFunMaxMusic` also stores its TeamCity settings in its own repository as Kotlin DSL
(`versionedSettings`, `format=kotlin`). Ours does not. That would be a new file layout in this
repo (`.teamcity/`), which `CLAUDE.md` says to ask about first — worth raising, not worth assuming.

The provisioning is scratchpad Python (`provision.py`, `trigger.py`, `redtest.py`), **not** repo
code, and it must stay that way: it reads the full-admin token, and §9 says that token goes in no
repository. Re-provisioning from scratch means rewriting them; the server is the record.

## Phase 2 — the release path. Not recommended

`scripts/release.sh` is the single release engine and it is a much harder CI target than it looks:

- **It signs.** `xcodebuild archive` with `DEVELOPMENT_TEAM=6FZN56WC8G`, then `-exportArchive`
  against `ExportOptions-AppStore.plist` or `ExportOptions-DeveloperID.plist`. A CI agent needs the
  certificates and provisioning profiles in a keychain it can unlock unattended.
- **It notarizes**, via `xcrun notarytool` with either explicit `--notarytool-key/-key-id/-issuer`
  or the keychain profile `no-spoilers-notarytool`.
- **It uploads**, via `xcrun altool --upload-app --apiKey/--apiIssuer`.
- **It writes to the repository.** `git commit -m "bump to vX.Y.Z (build N)"` followed by
  `git push`, plus `git tag`/`git push origin vX.Y.Z`, and for the Homebrew channel a commit and
  push in a second checkout. So the agent needs push rights to `main`, and **any trigger on push to
  `main` will retrigger itself** — that is the first thing to get wrong.
- **Its preflight refuses a dirty tree** (`release.sh:179`), which a CI checkout satisfies, and
  refuses a `(version, build)` pair App Store Connect already holds, which needs the read-only key
  at `~/.appstoreconnect/private_keys/AuthKey_S394C74APG.p8` — a path under the real `HOME`, not
  the redirected one Phase 1 relies on.

None of that is impossible. All of it is credential handling on a shared free-tier server, and it
buys back a path that currently works.

## Security notes carried over from the server doc

- The admin access token lives at `~/Documents/projects/teamcity/accesskey.txt` on Nick's machine.
  It is **full admin scope**, and §9 says plainly: not in any repo, do not commit it. Nothing in
  this repo should ever read it.
- `/app/rest` is behind Google SSO and **the token does not work against the public host** — REST
  access needs `ssh -N -L 8111:$TC_IP:8111 root@snowmonkey.co.uk`, forwarded to the *container's*
  bridge IP, looked up fresh each time. A `401` without the header proves you are on the tunnel; a
  `302` means you are still going through nginx.
- Agent identity lives in the `agent-conf` volume; losing it burns a licence slot.

## Still open

- Whether to move `funmax-xcode` to the root project so the two projects share one Xcode lock.
- Whether to adopt `versionedSettings` and keep the CI configuration in this repo.
- Whether to wire the root `NpomfretTeamCity` GitHub App connection up for commit statuses.
- Per-push triggering is on. The whole chain takes about a minute, so nightly was not needed; if
  that stops being true, the trigger is the thing to change.

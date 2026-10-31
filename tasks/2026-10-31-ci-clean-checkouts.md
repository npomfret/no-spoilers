# CI builds must start from a clean, empty checkout

Project: `no-spoilers`. Requested by Nick on 31 October 2026. Status: open.

Ensure every CI build starts from an empty source directory before checking out
the exact requested revision, unless a specific, justified exception is recorded.
Follow the [shared acceptance criteria](../../snowmonkey-proxy-common/tasks/2026-10-31-ci-clean-checkouts.md#shared-acceptance-criteria).

Local CI entry points found: `.teamcity`. Include server-managed builds and inherited templates in the inventory too.

## Inventory

Read from `.teamcity/settings.kts` and live `teamcity.py settings`. There are no
GitHub workflows, templates, artifact dependencies or paused configurations here.
All six shared one hash directory per agent (`work/aaa427f760df7d87`) and passed
it on with its `tmp/`: DerivedData, SwiftPM scratch and module caches.

| Configuration | Directory, under `work/` | Outputs | Credentials |
|---|---|---|---|
| `VerifyPython` | `no-spoilers-verify-python` | none | none |
| `VerifyXcode` | `no-spoilers-verify-xcode` | `tmp/` | none |
| `VerifySwiftTests` | `no-spoilers-verify-swift-tests` | `tmp/` | none |
| `Verify` | `no-spoilers-verify` | none, it has no steps but still checks out | none |
| `ShipIos` | `no-spoilers-ship-ios` | `tmp/`, plus the build temp directory | agent keychain and keys |
| `ShipMacos` | `no-spoilers-ship-macos` | `tmp/`, plus the build temp directory | agent keychain and keys |

`onTheAgent()` gives every one `cleanCheckout`, removal after the build
(`checkoutDir.expireHours = 0`) and `publishArtifacts = ALWAYS`. `Ship`'s artifacts
come from the build temp directory. The scripts rebuild everything in `tmp/`, and
`ci-publish.sh` sets the push URL and fetches tags on every run, so `Ship` needs
nothing from an earlier checkout.

No exception is needed. What outlives a build is outside the directory: the
agent's git mirror, and persistent signing state. The old hash directories are
left to TeamCity's own expiry.

## Evidence

All on `macstudio-2`, 31 October 2026. Temporary probe configurations, since
removed.

- **Seeds reach a reused directory, and clean checkout removes them.** One chain
  in one directory, so the agent's free-disk cleaner had no gap to act in. Twice:
  `ProbeSeed` 21661, `ProbeSeedSurvives` 21662 (all four seeds found),
  `ProbeCleanCheckout` 21663 (none found, `git status --ignored` empty, HEAD equal to
  `build.vcs.number`), within 22 seconds; then 21790, 21791, 21792. The seeds were
  a marker in `.git`, an untracked file, a changed tracked file, and ignored
  `tmp/` and `.build/` output.
- **Directory gone after every ending, evidence published first.** Each build
  below published `evidence/probe-sentinel.txt`, and the next run found its
  directory empty: failure 21343, self-cancel 21444 (status Canceled, sentinel still
  published), execution timeout 21699, then 21809.
- **The real configurations.** `Verify #190` (21063) and `#191` (21308) green.
  `ShipIos #23` (21310) delivered iOS 1.1.7 build 10047 from
  `no-spoilers-ship-ios`, and `ShipMacos #11` (21309) delivered macOS 1.1.7 build
  10048 from `no-spoilers-ship-macos`, both at `16d158d`.

An earlier separate control, `ProbeControl` 21341 and 21442, went red because the
free-disk cleaner deleted its directory between runs. Those builds and
`ProbeCleanCheckout` 20921, 21261 and 21360 prove nothing and are not counted.

## Residual risk

- The empty directories after failure, cancel and timeout show the outcome, not
  which mechanism did it: `expireHours = 0` or the free-disk cleaner. The clean
  checkout does not depend on either.
- Only `macstudio-2` was probed. `macstudio-3`'s allow-list excludes temporary
  configurations. All agents get the same settings.
- `Verify` is due to become a composite with no checkout, which changes its row
  above.

- [x] Inventory every CI build/leg and its checkout and output directories.
- [x] Apply clean checkout isolation and explicit cache/artifact handling.
- [x] Verify freshness and cleanup serially; record build IDs and evidence.
- [x] Record each justified exception with its build/path, reason, retained
  state and freshness/isolation controls, or record why no exception is needed.
  None is needed: see the inventory, and the comment beside `onTheAgent()`.

Keep paused builds paused. Creating this task does not change CI settings,
delete build data or claim the requirement is already satisfied.

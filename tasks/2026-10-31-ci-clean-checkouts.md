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

- [x] Inventory every CI build/leg and its checkout and output directories.
- [ ] Apply clean checkout isolation and explicit cache/artifact handling.
  Written in `.teamcity/settings.kts`; applies only once it reaches `main`.
- [ ] Verify freshness and cleanup serially; record build IDs and evidence.
- [ ] Record each justified exception with its build/path, reason, retained
  state and freshness/isolation controls, or record why no exception is needed.
  Recorded above and beside `onTheAgent()`; ticked once the probes confirm it.

Keep paused builds paused. Creating this task does not change CI settings,
delete build data or claim the requirement is already satisfied.

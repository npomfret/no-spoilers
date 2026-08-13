# Task 17: Homebrew is being treated as the core macOS product

**Status: OPEN, diagnosis only. No changes proposed for approval yet — the decisions at the bottom
come first.**

Raised 2026-08-13: the macOS release process feels very different from the iOS one, and Homebrew
looks like it is being treated as the main product rather than an add-on.

Half of that is right, and the half that is wrong matters, so both are written down below.

---

## What is already shared, and should not be "fixed"

**The release engine is not duplicated.** `scripts/release.sh` is one engine with a
platform × channel matrix, and everything platform-specific is nine lines of derived values:

```
release.sh:91-105    SCHEME / DESTINATION / PRODUCT_BASENAME / package name / ALTOOL_TYPE
```

`ship.sh`, `ship-appstore.sh`, `ship-homebrew.sh` and `ship-ios.sh` are 15–50 line argument
wrappers with no logic in them. Version bump, commit, push, tag, clean and archive are all on the
shared path (`release.sh:127-173`) and run identically for both platforms.

So there is no second implementation to converge, and this task must not produce one. What differs
is **the channel set and the CI coverage**, not the code.

---

## Where Homebrew is treated as the core product

Five places, all in `release.sh`:

1. **It is the default.** `PLATFORM="macos"`, `CHANNEL="developer-id"` (`release.sh:51-52`). Running
   the engine bare ships Homebrew. The add-on is what you get when you ask for nothing.

2. **It runs first in `--channel both`, and it can block the store.** developer-id is
   `release.sh:177-244`, app-store is `release.sh:248`. Both export from the *same archive*, which
   is already built and valid by line 173. But notarization is a multi-minute wait on an Apple
   service (`release.sh:194-205`), and under `set -e` a notary failure kills the run **before the
   Mac App Store upload is attempted**. An add-on channel failing takes the core product down with
   it, having already done the expensive part successfully.

3. **It owns the git tag.** `tag_version` is called at `release.sh:227`, inside the developer-id
   block, immediately before `gh release create`. It is idempotent and also called on the app-store
   path (`:284`, `:289`), so nothing is broken — but in a `both` run the tag `v1.1.1` comes into
   existence as a Homebrew release and the store upload inherits it.

4. **It owns the unqualified name.** Every other artifact is `NoSpoilersMac-*` or `NoSpoilersApp-*`.
   The Homebrew zip is `NoSpoilers-${VERSION}.zip` (`release.sh:179`).

5. **GitHub releases exist only to serve it.** There is no other consumer of
   `gh release create` — it is a CDN for the cask, and the cask is the only reader of the SHA256.

---

## The real asymmetry, which is not about Homebrew at all

| | macOS | iOS |
|---|---|---|
| CI build | **none** | Xcode Cloud, every push to `main` |
| Automated test gate before shipping | **none** | `ci_pre_xcodebuild.sh` runs `verify-core-tests.sh` |
| Routes to the store | local `release.sh` | local `release.sh` **and** Xcode Cloud |
| Beta channel | **none** | TestFlight |
| Build-number bands in use | 10001+ | 10000+ *and* 1…n |

Verified 2026-08-13 — the product holds exactly one workflow and one action:

```
7A43B70B-…  'NoSpoilers iOS'  enabled=True
    ARCHIVE   platform=IOS  scheme=NoSpoilersApp
```

**Homebrew is doing TestFlight's job on macOS.** It is the only macOS path with any velocity: ship
a build, users have it in minutes, no review. That is why it feels like the core product — it is
the only fast one. Demoting it to an add-on without giving macOS a beta channel does not simplify
anything, it just removes the one channel that works.

Note also that the macOS `ARCHIVE` action was **deliberately deleted** during the 2026-08-13
product recreation (task 15) — the wizard added it unrequested and it was removed to keep the
restore minimal. That was the right call under the circumstances and is not a decision anyone
made on the merits.

---

## Defects worth fixing whatever is decided about the philosophy

These are independent of the add-on question.

- **The version bump is committed and pushed before anything is built.**
  `release.sh:147-154` commits and pushes; the archive is at `:164`. A build failure leaves a
  pushed `bump to vX (build N)` commit and no artifact anywhere. `ship.sh` invokes the engine
  twice, so a macOS success followed by an iOS failure leaves **two** pushed bump commits and one
  platform shipped.

- **One `ship.sh` run produces two different build numbers for one version.** Each invocation
  bumps `CURRENT_PROJECT_VERSION` independently (`release.sh:134-142`), which is why 1.1.1 carries
  10001 on macOS and 10002 on iOS. Harmless today, but the docs say the channels are
  "version-locked" and the build numbers visibly are not.

- **The Homebrew tap path is unchecked and reaches outside the repository.**
  ```
  release.sh:236   HOMEBREW_TAP_DIR="$(dirname "$(realpath "$0")")/../../homebrew-tap"
  ```
  No existence check, no branch check, no clean-tree check. The checkout is present today
  (`../homebrew-tap/Casks/no-spoilers.rb`). If it were missing, `sed -i ''` fails *after*
  notarization has completed and the GitHub release has been published. **Per the repo's fail-fast
  rule this should be a precondition at the top of the run, not a discovery at the end of it.**

- **Re-running after a partial failure is not safe.** `tag_version` guards the tag, but
  `gh release create` at `:230` is unguarded. *(Unverified — check `gh`'s behaviour on an existing
  release before acting on this.)*

- **The two writing tools have opposite safety postures.** `testflight_distribute.py` is dry-run by
  default and needs `--apply`. `release.sh` has no dry run and pushes to two repositories.

---

## Options

Not mutually exclusive; roughly increasing cost.

**A. Reorder and decouple the channels.** Run app-store before developer-id in `both`, and let a
notary failure report loudly without taking the store upload with it. Cheap, removes the worst
coupling, changes nothing about what ships.

**B. Make the defaults say what is true.** If the App Store is the core product, the bare default
should not be `developer-id`. Possibly no default at all — require `--channel` explicitly.

**C. Move the bump after the archive**, so a failed build leaves the repo clean.

**D. Give macOS the CI and beta channel it lacks.** Add the macOS `ARCHIVE` action back to the
Xcode Cloud workflow, gated by the same `ci_pre_xcodebuild.sh` hook, delivering to TestFlight for
macOS. This is the change that would actually make the two platforms symmetric, and it is the one
that would let Homebrew become a genuine add-on rather than a demoted core.
**Read task 15 before touching that workflow** — editing it is not the same operation as creating
one, but the blast radius of getting it wrong now includes a sibling project.

---

## Decisions

1. **DECIDED 2026-08-13: the App Store is the core product. Homebrew is an add-on.**
   Options A and B are done — see below. On iOS the core product is specifically **the live
   updating widget**, which is also the 4.2.2 argument in task 16; the two tasks meet there.
2. **OPEN — does macOS get Xcode Cloud and TestFlight (option D)?** Until it does, "Homebrew is an
   add-on" is an aspiration, because nothing else on macOS is fast.
3. **OPEN — how much of the defect list to take now**, given task 16 is the live priority. Note
   that A reduced the cost of two of them: a Homebrew tap or notary failure can no longer lose the
   store upload, only the Homebrew publish.

### Done: A and B

`release.sh`, 2026-08-13:

- **App Store now runs before Developer ID** in `--channel both`. Both export from the same
  already-valid archive, so this costs nothing and removes the coupling. A Homebrew failure still
  fails the run loudly under `set -e`; it can no longer take the upload with it. The reason is
  written into the file above the channel so it does not get "tidied" back.
- **`--platform` and `--channel` are now required.** The old defaults were `macos` +
  `developer-id`, so a bare invocation shipped the add-on. All four `ship-*.sh` wrappers already
  passed both explicitly, so nothing else changed.

Verified: `bash -n` clean on all ten shell scripts; bare, platform-only and invalid-combination
invocations each exit 1 before touching the working tree. **Not verified by a real release** — that
needs an actual ship and has not been run.

---

## Verification

Whatever is done here:

- [ ] `scripts/ship.sh` still ships all three channels from one version, proven by a real run
- [ ] A deliberately failed channel leaves no pushed bump commit for an unshipped build
- [ ] The four `scripts/verify-*.sh` wrappers pass
- [ ] `scripts/ci_health.py` clean, and both Xcode Cloud products still resolve by id
- [ ] `docs/guides/building.md` updated in the same change — it is the canonical description and is
      currently accurate

# Task 17: Homebrew is being treated as the core macOS product

**Status: OPEN on two deliberately-deferred pieces (updated 2026-08-14). Every decision is made.
A, B, C, four of the five defects and option D are done and proven: run 15 archived both platforms,
and macOS build 15 is in the hands of the internal testers. macOS now has CI, a test gate and a
beta channel, so "Homebrew is an add-on" is finally a description rather than an aspiration — the
channel stays, it is just no longer the only fast way to get a Mac build to anyone. What is left is
deferred on purpose, not stuck: `appstore_status.py` still reports one platform, so a stranded Mac
build is invisible to it, and `release.sh` still has no `--dry-run`.**

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

Five places, all in `release.sh`. **Line numbers below are as they stood on 2026-08-13 and have
since moved; 1 and 2 are fixed.** 4 is left alone deliberately — the cask builds its download URL out
of that exact name (`…/download/v#{version}/NoSpoilers-#{version}.zip`), so renaming the artifact
is a coordinated change across two repositories in exchange for consistency in a filename.

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

As it stood 2026-08-13. The CI and test-gate rows were closed on 2026-08-14; the beta row was not.

| | macOS | iOS |
|---|---|---|
| CI build | ~~**none**~~ → Xcode Cloud, same workflow | Xcode Cloud, every push to `main` |
| Automated test gate before shipping | ~~**none**~~ → the same `ci_pre_xcodebuild.sh` | `ci_pre_xcodebuild.sh` runs `verify-core-tests.sh` |
| Routes to the store | local `release.sh` **and** Xcode Cloud | local `release.sh` **and** Xcode Cloud |
| Beta channel | TestFlight, via `--platform macos` | TestFlight |
| Build-number bands in use | 10001+ *and* 1…n | 10000+ *and* 1…n |

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
product recreation — the wizard added it unrequested and it was removed to keep the
restore minimal. That was the right call under the circumstances and is not a decision anyone
made on the merits. **It was put back on the merits on 2026-08-14**, by hand and by id rather than
by wizard; see "Done: option D" below.

---

## Defects worth fixing whatever is decided about the philosophy

These are independent of the add-on question. **Four of the five were fixed 2026-08-14** — see
"Done: the defect list" below. The one left open is the last.

- ~~**The version bump is committed and pushed before anything is built.**~~ FIXED.
  A build failure left a pushed `bump to vX (build N)` commit and no artifact anywhere, and
  `ship.sh` invokes the engine twice, so a macOS success followed by an iOS failure left **two**
  pushed bump commits and one platform shipped.

- ~~**One `ship.sh` run produces two different build numbers for one version.**~~ FIXED.
  Each invocation bumped `CURRENT_PROJECT_VERSION` independently, which is why 1.1.1 carries
  10001 on macOS and 10002 on iOS. Harmless in itself, but the docs said the channels were
  "version-locked" and the build numbers visibly were not.

- ~~**The Homebrew tap path is unchecked and reaches outside the repository.**~~ FIXED.
  `HOMEBREW_TAP_DIR="$(dirname "$(realpath "$0")")/../../homebrew-tap"` had no existence check. If
  the checkout were missing, `sed -i ''` failed *after* notarization had completed and the GitHub
  release had been published.

- ~~**Re-running after a partial failure is not safe.**~~ FIXED, and the note to verify `gh` first
  was right to be there: **`gh release view` is the honest probe** — exit 0 for an existing
  release, exit 1 for a missing one (checked against `v1.1.1` and `v99.99.99` on 2026-08-14).

- **OPEN — the two writing tools have opposite safety postures.** `testflight_distribute.py` is
  dry-run by default and needs `--apply`. `release.sh` has no dry run and pushes to two
  repositories. Not taken because a real `--dry-run` has to guard every mutating command in the
  engine, and half its value — knowing the run cannot die on a missing tap — is now in preflight.

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
**Read the Xcode Cloud bullets in `docs/guides/building.md` before touching that workflow** —
editing it is not the same operation as creating
one, but the blast radius of getting it wrong now includes a sibling project.

---

## Decisions

1. **DECIDED 2026-08-13: the App Store is the core product. Homebrew is an add-on.**
   **Reaffirmed 2026-08-14: the Homebrew channel stays. It is less important, not unwanted.**
   "Add-on" is a statement about priority and ordering, never a plan to retire the channel — do not
   read anything in this file, or the App Store running first in `--channel both`, as licence to
   delete it. It is a real distribution route with real users on it.
   Options A and B are done — see below. On iOS the core product is specifically **the live
   updating widget**, which is also the 4.2.2 argument in task 16; the two tasks meet there.
2. **DECIDED 2026-08-14: yes — macOS gets Xcode Cloud (option D).** The CI half is done; the
   TestFlight half is not. See below.
3. **DECIDED 2026-08-14: take all of the defect list except the dry run.** Option C and the other
   three are done; see below. The dry run is the one that needs new machinery rather than
   reordering existing machinery, and preflight already removes its most-cited benefit.

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

### Done: the defect list, 2026-08-14

- **Commit and push moved below the archive** (`release.sh`). The sed stays above it, so the
  archive is still built from a working tree that agrees with the flags it is passed; only the
  commit waits for an artifact to exist. An `ERR` trap between the two reports that the project is
  modified and unpushed. It deliberately does not revert — that file is not exclusively ours.
- **`--build N`** added to `release.sh`, and `ship.sh` chooses one number for the whole run.
- **`current_build_number` and `pbxproj_path`** added to `_version.sh`, which is where shared
  release shell already lives. `ship.sh` needs the number before it calls the engine, and two
  readers of that pbxproj line would drift.
- **Preflight** section in `release.sh`: `--channel developer-id|both` now resolves the tap and
  fails at the top of the run if the cask file or its git checkout is missing.
- **`gh release create` guarded** by `gh release view`, falling back to `gh release upload
  --clobber`.

Verified 2026-08-14 without shipping anything:

| check | evidence |
|---|---|
| `bash -n` on all eleven shell scripts | clean |
| helpers read the project | `current_build_number` → `10002`, matching the pbxproj line |
| argument validation | bare, platform-only, `ios + developer-id`, `--build abc`, `--build 1e3` all exit 1, working tree untouched |
| tap preflight fires | missing cask (both `developer-id` and `both`) and non-git tap dir each exit 1 before any build |
| tap preflight is scoped | `--channel app-store` runs straight past it |
| **failed archive leaves no commit** | throwaway git repo + unbuildable project: archive failed, trap reported, `git log` still 1 commit, nothing pushed, pbxproj left modified |
| `--build` pins and is idempotent | 500 → 501 unpinned; `--build 777` → 777; second invocation with 777 → 777 |
| `ci_health.py` | PASS, both products resolve by id |

Not run: the four `verify-*.sh` wrappers. This change is shell-only and none of them source
`_version.sh` (`release.sh` and `ship.sh` are its only readers), so they answer nothing about it.

### Done: option D, the CI half, 2026-08-14

A second `ARCHIVE` action, scheme `NoSpoilers`, platform `MACOS`, added to the existing workflow
`7A43B70B-3311-4954-A625-AB82333B6503` by `PATCH /v1/ciWorkflows/{id}` with the App Manager key.
The full before/after is in `docs/guides/building.md`, which is the canonical description.

**One workflow, not two.** Actions in a workflow share the run number, so one commit now produces
iOS build N and macOS build N. Two workflows would have given the platforms different build numbers
for the same commit — the exact defect `ship.sh` was fixed for two hours earlier in this task.

Checked before writing, because `building.md` warns that a spent `(version, build)` pair goes green
and then dies at *"Preparing build for App Store Connect failed"*:

```
IOS     1.1.1  builds 1–14, 10002        next run is 15 — free
MAC_OS  1.1.1  build 10001 only          next run is 15 — free
```

The macOS train has never used a CI-band number; every pre-2026-08 macOS build was build 1 or 2 of
its own version, and `release.sh` sits at 10001. The bands do not collide.

Verified: the workflow's before/after diff is the new action and `lastModifiedDate`, nothing else —
name, branch condition, `containerFilePath`, `isEnabled` and `clean` are untouched. `ci_health.py`
PASS afterwards, with `super-funmax-music` still pointing at its own repository.

**Proven by run 15, 2026-08-14**, on commit `0660ca0` — the first Xcode Cloud run to archive macOS:

```
Archive - iOS     COMPLETE / SUCCEEDED     started 20:43:41.432Z
Archive - macOS   COMPLETE / SUCCEEDED     started 20:43:41.755Z
RUN               COMPLETE / SUCCEEDED

IOS     1.1.1 build 15  VALID   uploaded 13:47:40
MAC_OS  1.1.1 build 15  VALID   uploaded 13:46:14
```

Both actions dispatched from one commit 300ms apart, and **both platforms carry build 15** — the
one-workflow choice doing the job it was made for. Signing, the one thing that could not be
predicted from here, needed nothing: Xcode Cloud provisioned macOS App Store distribution itself,
on a project that had only ever signed macOS on a laptop.

Note what "SUCCEEDED" did *not* have to mean. `building.md` warns that a green run is not a
delivered build, so the archive being green was checked against App Store Connect separately; both
builds are `VALID` there.

### Open: option D, the TestFlight half

The action uploads. Nothing distributes it, and *"forgetting it looks exactly like success"* is
this repo's own phrasing for that failure. **Measured, not assumed** — macOS build 15 immediately
after run 15:

```
GET /v1/builds/1cbcb39d-8aef-4d9d-b445-30832b48ab54?include=betaGroups
    processingState VALID, expired false, included: []
```

`VALID` and in no group at all. Every other signal reads as success.

**Half done, 2026-08-14, and split on purpose.** Delivery was asked for; the report was not.

**Done — `testflight_distribute.py --platform {ios,macos}`.** Build selection only: `gather` takes
the platform, and everything else in that script was already platform-agnostic. It defaults to
`ios`, so no existing invocation changes meaning. One run does one platform deliberately — every
Xcode Cloud run now archives both, and a Mac build going to testers should be a decision somebody
made, not a side effect of shipping iOS.

Two selftest guards came with it, both about the same class of fault: the default here must equal
`asc.TESTFLIGHT_PLATFORM`, or the report would confirm a delivery on the platform nobody delivered
to; and `macos` must map to `MAC_OS`, because Apple spells this platform `MAC_OS` in the
`/v1/builds` filter and `MACOS` in the Xcode Cloud action, and both spellings now appear in this
repo. 27 cases, 0 failures.

Proven end to end on macOS 1.1.1 build 15:

```
before   VALID, include=betaGroups: []
after    groups: ['Internal'], internalBuildState IN_BETA_TESTING
         whatsNew 'task 17 option D: give macOS the CI it never had

                   Build 15 from 0660ca06996f'
```

The note is the build's own, traced to run 15's commit — the exact failure `repair_note` exists to
prevent, and it works unchanged on macOS.

**Still open — the report.** `scripts/appstore_status.py` covers one platform, so a stranded Mac
build and no Mac build print identically. Threading it through means `distribution`, `attention`,
`render` and the fixtures, and **hoist the tester-group fetch out of `distribution` first**: the
groups are app-wide, so a naive per-platform loop would fetch and print them twice.

The workflow was renamed `NoSpoilers iOS` → **`NoSpoilers`** on 2026-08-14, once it stopped being an
iOS-only workflow. `PATCH /v1/ciWorkflows/{id}` with `attributes.name` alone; the actions, branch
condition and enabled flag are untouched by a name-only patch, and `ci_health.py` PASS afterwards.
Do not call it `Default` — that is how the wizard's victim goes unnoticed.

---

## Verification

Whatever is done here:

- [ ] `scripts/ship.sh` still ships all three channels from one version, proven by a real run
      — **still the gap; everything above is proven short of an actual ship**
- [x] A deliberately failed channel leaves no pushed bump commit for an unshipped build
- [ ] The four `scripts/verify-*.sh` wrappers pass — not applicable to a shell-only change
- [x] `scripts/ci_health.py` clean, and both Xcode Cloud products still resolve by id
- [x] `docs/guides/building.md` updated in the same change — it is the canonical description and is
      currently accurate

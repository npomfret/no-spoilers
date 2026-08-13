# Task 15: Xcode Cloud "Create Workflow" destroys a sibling project's product

**Status: RESOLVED in practice, OPEN as a hazard.** As of 2026-08-13 08:04Z **both projects hold a
working Xcode Cloud product at the same time** — the first time that has ever been true. The
underlying wizard fault is not fixed and will bite the next person who creates carelessly.

Read this before touching Xcode Cloud from either `no-spoilers` or `super-funmax-music`. The two
projects share Apple team `6FZN56WC8G`, and a fault in Xcode's Create Workflow wizard destroyed
**three** Xcode Cloud products between 2026-08-08 and 2026-08-12, plus one deliberate deletion. It
is invisible from the victim's side.

This file is written for both projects. Times are UTC where they came from the API (`Z`) and local
BST otherwise; the earliest entries mix the two and could not be reconciled afterwards.

---

## The three rules

1. **Only run Create Workflow when the team is empty *by id*.** Every successful creation has
   started from zero. Every attempt with a product already present has seized it — three for
   three.
2. **Never trust `GET /v1/ciProducts`.** It is a cache and it has lied in both directions. The
   by-id call is the only honest signal. Run `scripts/ci_health.py`, which re-fetches every listed
   id.
3. **If the wizard errors, stop. Do not retry.** The damage happens *before* the error is shown,
   so retrying destroys the next product. This single reflex accounts for most of the four losses.

And one that follows from them: **the wizard seizes the product that already exists, so the first
mover is the victim and the second mover merely gets an error.** Whoever creates first is the one
at risk. Order accordingly, deliberately.

---

## Current state, 2026-08-13

**Two live products, coexisting.** Two ghosts also remain in the listing; ignore them.

```
9C40B27D-5C9B-4AB2-A9A2-6B97616BAA3F  "NoSpoilersApp"   created 08-13T07:53:56Z
  app 6761343835  pomocorp.NoSpoilers.NoSpoilersMac    repository npomfret/no-spoilers
  workflow 7A43B70B-3311-4954-A625-AB82333B6503  "NoSpoilers iOS"
  run #1 GIT_REF_CHANGE SUCCEEDED, commit 4ab0e12

340CDC9B-A9BA-4B2D-A11C-3548AA5E087F  "FunMaxMusic"     created 08-13T08:04:25Z
  app 6770023782                                        repository npomfret/super-funmax-music

GHOSTS (listed, 404 by id — not products):
  F6A2F0EB-…  deleted 08-12 15:30Z, still listed 18+ hours later
  28472948-…  deleted 08-12 evening
```

---

## The experiment, and what it did and did not prove

The abort message is *"Workflow name already exists."* Every product the wizard creates gets a
workflow called `Default`. If workflow names collide **team-wide** rather than per-product, then a
second creation is refused on the name — and the refusal happens after the rename and repoint,
which is the entire fault. That fits every failure and every success without requiring "a team can
only hold one product" to be true, which is absurd on its face.

So `super-funmax-music` was deleted first and recreated **second**, into a team whose only workflow
was named `NoSpoilers iOS`, and its own was named `FunMaxMusic iOS`.

**Result: it created cleanly. Nothing was seized.** `9C40B27D` and its `/app` both answered `200`
throughout, checked from the other project immediately after.

**But two variables changed at once, and the honest reading is weaker than the result looks:**

- the workflow names were made unique, **and**
- the ordering was reversed so the second mover was the one with nothing to lose

This single run cannot separate "the unique name fixed it" from "going second is what matters"
from "the fault needed some state that is not present today". Testing the name theory properly
would need a run with two workflows both called `Default` and nothing else different — which
nobody should do now that both products are real and accumulating history. Credit for insisting on
this caveat goes to the `super-funmax-music` session; the temptation was to write this up as proof.

**Operationally it does not matter much.** Do both: create only into a team empty by id, and never
let two workflows share a name. They cost nothing and one of them is doing the work.

If the fault ever recurs, the bug report to Apple is `GET /v1/ciProducts/{id}/app` returning
**HTTP 500** on a product Apple's own wizard mangled — unambiguous and reproducible.

---

## The mechanism

Create Workflow does not reliably create. With a product already on the team it takes that
existing record and:

1. **renames it** to the project that ran the wizard
2. **repoints its primary repository** at the repo that ran the wizard
3. **strips its `app` relationship** — `GET /v1/ciProducts/{id}/app` then returns `500`
4. **aborts** with *"Workflow name already exists"*

The abort happens *after* steps 1–3, so **a failed wizard run is not a no-op.** The workflow inside
the seized product is left untouched and still valid, which is what makes this invisible.

**The trigger follows the product's repository attachment, not the workflow's.** So the victim's
workflow still reads as perfectly configured and enabled while their pushes build nothing. Nothing
on their side reports it. The first occurrence went unnoticed for four days.

An orphaned product also makes the whole list unlistable, which used to be read as the *cause* of
the next hijack. It is a consequence.

---

## History

| # | When | Wizard run from | Took | Result |
|---|---|---|---|---|
| 1 | 2026-08-08 | `no-spoilers` | `EDF20772` (FunMaxMusic's) | renamed `NoSpoilersApp`, repointed at `no-spoilers`. Unnoticed for 4 days. |
| 2 | 2026-08-12 ~11:4x | `super-funmax-music` | `1F3A0BBD` (ours) | renamed `FunMaxMusic`, repointed at `super-funmax-music` |
| 3 | 2026-08-12 14:53 | `no-spoilers` | `CADFB659` (FunMaxMusic's) | taken mid-life with 5 runs, 3 succeeded |
| 4 | 2026-08-12 15:30 | — | `F6A2F0EB` (ours) | **not the fault** — a deliberate `DELETE` from their side, see below |

Successful creations, all four from a team empty by id: task 14's original, `CADFB659`
(2026-08-12T10:53:48Z), `28472948` (2026-08-12T15:39:17Z), `9C40B27D` (2026-08-13).

### Occurrence 1 and what task 14 concluded

`tasks/14-xcode-cloud-testflight.md` diagnosed the wizard failure correctly and called the outcome
benign — retrying Create Workflow "made a **new** product and left the broken one in place". It did
not. It took the sibling's product, and that project stopped building the same day. **That single
wrong sentence is the direct cause of occurrences 2 and 3**, because it made retrying look free.

### The 11:50 state — both projects crossed

Both products orphaned, both `500`, repositories swapped, each holding a workflow that built the
*other* project. `GET /v1/ciProducts` returned `0` across eight checks over ten minutes while both
still resolved by id. Apple's system status reported Xcode Cloud healthy.

Both were deleted at ~11:55 (`204`, then `404` each), because `ciProducts` accepts no `PATCH` —
neither the app link nor the repository attachment can be repaired. `DELETE` takes the workflow and
all run history with it. Lost: this repo's runs #1–#17, FunMaxMusic's #1–#28.

### Occurrence 3 — the one that proved the rule was backwards

This repo ran the wizard against a list reporting exactly `1` — FunMaxMusic's recreated product,
listable, `/app` resolving `200`, `ci_health.py` `PASS` minutes earlier — on the strength of the
guidance then in this file. It seized that product.

```
CADFB659  created 10:53:48Z as FunMaxMusic's
  name         FunMaxMusic          ->  NoSpoilersApp
  repository   super-funmax-music   ->  no-spoilers
  app          6770023782           ->  stripped, 500
  workflow     EFDA9C91 "Default", unchanged, still building FunMaxMusic
  runs         1-5, last 13:45, three SUCCEEDED — a working product, taken mid-life
```

### Occurrence 4 — not the fault

`F6A2F0EB` was deleted deliberately from the `super-funmax-music` side at ~15:30Z, config recorded
first, and their wizard then ran at 15:39:17Z into a team empty by id. Their commits `1e44b3d`
(15:30:14Z) and `938374f` (15:41:15Z) record both halves, the second noting *"a stale list is not
an occupied team."*

No rename, no repoint, app link intact in the listing, `404` on every by-id call — a completed
`DELETE` plus a stale list. **It cost us the experiment**: their workflow is named `Default` and
ours was named `NoSpoilers iOS` precisely so the two could not collide, but ours was gone before
their wizard started. Nothing was tested.

### 2026-08-12 evening — the ordering reversed

With the owner's approval, `28472948` was deleted (config recorded, commit `89ec623`) so that
**this repo would be the one exposed**. Reasoning: the wizard takes the existing product, so
whoever creates first is the victim. On 2026-08-12 we went first on the argument that our product
was cheapest to lose, and FunMaxMusic paid for it twice. Reversing the order means FunMaxMusic
ends up working in *every* branch — if their creation seizes ours, they simply create again from
an empty team, which is a procedure that now works reliably.

---

## What this file got wrong, and when

Kept because the corrections are the most useful thing here. Every one of them was believed,
acted on, and cost something.

| Claim | Reality |
|---|---|
| *"Retrying Create Workflow makes a new product and leaves the broken one in place"* (task 14) | It seizes the sibling's product. Caused occurrences 2 and 3. |
| *"Do not run the wizard while `GET /v1/ciProducts` returns an empty list"* | Backwards. Empty **by id** is the only state creation has ever worked from. This wording caused occurrence 3. |
| *"Two products cannot coexist on this team"* | Never demonstrated, and now disproved — both exist as of 2026-08-13 08:04Z. Asserted from a list total that was counting a ghost. |
| *"Starting a run by hand primes the trigger"* | It does not. Tested directly: manual run at 15:52 succeeded, the 15:58 push still produced nothing. |
| *"The trigger takes an hour or more"* | One sample. Later products triggered in 25 minutes and 5 minutes. There is no number. |
| *"Set Distribution Preparation to TestFlight"* | No such option. It is **App Store**, and it defaults to **None**. |

The pattern is worth naming: **every recorded *fact about the world* here has rotted — product
ids, live versions, which paths run. Everything that *derives* its answer has stayed correct.**
`find_ci_product`, which looks a product up by the app it builds, survived three hijacks; the
recorded `CI_PRODUCT_ID` beside it took a whole script down, dry run included.

---

## The list is a cache and it lies in both directions

- **2026-08-12 11:50** — returned `0` across eight checks over ten minutes while two products still
  resolved by id.
- **2026-08-12 15:30 → 2026-08-13 09:00+** — kept naming `F6A2F0EB` for **eighteen hours and
  counting** after a `DELETE` that answered `204`, app relationship and all, while every by-id call
  returned `404`.

**Only the by-id call is honest.** A listed product that `404`s by id is a *ghost*: it must not be
counted, and its sub-resource `404`s must not be reported as faults. `asc.ci_products` re-fetches
every listed id and marks ghosts — counting one is exactly how this repo concluded that two
products had coexisted on a team that had never held two.

Expect a newly created product **not** to appear in the list immediately. Check it by id.

### The ghost bug bites twice, and the second bite is the dangerous one

**A ghost keeps its `app` relationship in the listing.** So this repo's own deleted product claimed
this repo's app exactly as loudly as the live one, and `select_ci_product` — which deliberately
stops rather than guess when two records claim one app — fired on a perfectly healthy team:

```
2 Xcode Cloud products claim this app: 9C40B27D-…, F6A2F0EB-…
```

`testflight_distribute.py` was dead on 2026-08-13 for exactly this reason. The
`super-funmax-music` session hit the same class of bug independently and warned about it: they had
made their listing helper ghost-safe and left a later call that took an id from that list and
fetched its `/workflows` with an unguarded `get`, which raised on the `404`. Their words, and they
are the general lesson:

> the ghost lesson was learned in one function and not the other. If your invariant is only
> enforced at the listing site, check every other path that takes an id from that list.

So ghost-detection now lives in `asc.ci_products`, the one place both tools get their products
from, rather than in each caller. `ci_health.py` consumes the flag instead of re-deriving it —
this concern living in one function and not another is the bug itself.

---

## The trigger is on a delay, and the spread is wide

After creation, pushes are ignored for a while. Samples:

| Product | Created | First `GIT_REF_CHANGE` | Delay |
|---|---|---|---|
| `CADFB659` | 10:53 | 13:01 | 79 min |
| `28472948` | 15:39 | 16:04 | 25 min |
| `F6A2F0EB` | 14:08 | never, across 4 pushes | died at 50 min |
| `9C40B27D` | 08-13 07:53:56Z | 07:58:57Z | **5 min** |

Five minutes, twenty-five, seventy-nine, and never. **There is no rule here** — do not plan around
a number, and do not read a quiet first push as a broken workflow.

`scmRepositories/{id}` `lastAccessedDate` tells you whether Apple has looked at the repo at all —
on `F6A2F0EB` it never advanced past its own checkout.

Use `POST /v1/ciBuildRuns` with the workflow relationship for anything urgent; it starts a run
immediately (`startReason: MANUAL`). **Do not go near the wizard to "fix" a dead trigger** — a dead
trigger looks exactly like a misconfigured workflow, and recreating is what destroys products.

---

## Restore baselines

Recorded so that whichever product the next wizard run takes can be rebuilt. Each is recorded by
the *other* project, because the victim is the one who will not notice.

### `no-spoilers` — current, 2026-08-13

```
product           9C40B27D-5C9B-4AB2-A9A2-6B97616BAA3F  "NoSpoilersApp"
app               6761343835  pomocorp.NoSpoilers.NoSpoilersMac
repository        npomfret/no-spoilers  (b36f1212-d272-4b37-9ba0-50c3277fd1f2)
workflow          7A43B70B-3311-4954-A625-AB82333B6503  "NoSpoilers iOS", enabled, not locked
containerFilePath NoSpoilers/NoSpoilers.xcodeproj
branch            main (exact, not prefix), autoCancel true, no file/folder rule
pull requests     no start condition; no tag or schedule condition
action 1  ARCHIVE  "Archive - iOS", scheme NoSpoilersApp, IOS, APP_STORE_ELIGIBLE,
                   isRequiredToPass true
```

No TEST action by design — the test gate is `NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh`, which
runs `scripts/verify-core-tests.sh` before every `xcodebuild`. Xcode Cloud does not gate delivery
on its TEST action, so a failing pre-build hook is the only thing that actually stops a bad build
reaching a tester.

### `super-funmax-music` — last known good, 2026-08-12 17:2x

```
product           28472948-8E80-4EF5-BEF7-7D9A75871315  "FunMaxMusic", created 2026-08-12T15:39:17Z
app               6770023782
repository        npomfret/super-funmax-music  (3706b1f0-bfe2-472b-b936-b24b6043d789)
workflow          91354094-734F-4096-A93A-17A502322EE5  "Default", enabled, clean, not locked
containerFilePath apple/FunMaxMusic/FunMaxMusic.xcodeproj
branch            main (exact, not prefix), autoCancel true, no file/folder rule
pull requests     no start condition; no tag or schedule condition
action 1  TEST     "UnitTests - iOS", scheme FunMaxMusic, IOS, test plan "UnitTests",
                   Recommended iPhones / iOS 26.5 simulator, isRequiredToPass true
action 2  ARCHIVE  "Archive - iOS", scheme FunMaxMusic, IOS, APP_STORE_ELIGIBLE,
                   isRequiredToPass true
```

**Recreate it with the workflow named `FunMaxMusic iOS`, not `Default`.**

---

## Running the wizard: what Xcode actually shows

The recorded settings did not match the UI, which cost time mid-repair.

- **Quit Xcode completely (⌘Q) and reopen first.** It reads a cached product list.
- **There is no "TestFlight" option.** It is *Distribution Preparation* → **App Store**, which
  produces `APP_STORE_ELIGIBLE`. It **defaults to `None`**, which archives and uploads nothing —
  easy to leave wrong and hard to notice.
- **"Exact match" is not a control.** *Custom Branches* with `main` typed in is exact; the API
  records `isPrefix: false`.
- **The wizard fits extra actions from the schemes it finds.** It has twice added an
  `Archive - macOS` action nobody asked for. Delete it in the workflow editor before saving — it
  would upload macOS builds numbered from `CI_BUILD_NUMBER` into the band `scripts/release.sh`
  reserves from 10000, and open version records nobody asked for. **The workflow editor is safe;
  only the create wizard is dangerous.**
- **Press Close, not Start Build**, until the actions have been verified over the API.

---

## Tooling

`scripts/ci_health.py` — read-only, `GET`s only, exit 0 clean / 1 needs a person. Run it
immediately after any wizard run and before trusting any Xcode Cloud state. It asserts
non-interference **in both directions**:

- no product of ours attached to another project's repository
- **no product of theirs attached to ours** — the one nothing else checks, and the one that costs
  somebody else four days

It also excludes ghosts, and reads this repo's identity from `git remote get-url origin` rather
than a constant, because a checker holding a stale idea of which repo is "ours" would confirm a
hijack as healthy.

**Never identify a product by name or by a recorded id.** `asc.find_ci_product` matches on the app
the product builds. After a hijack the record named `NoSpoilersApp` was the sibling's and the one
named `FunMaxMusic` was ours — name-matching would have pointed this repo's tooling straight at
another project's product. `app` is the field the fault strips rather than forges, so a seized
record matches nothing instead of matching wrongly. Both behaviours are replayed against the real
2026-08-12 state in `appstore_status.py --selftest` and `ci_health.py --selftest`.

`ciProducts` supports **only** `DELETE`, `GET_COLLECTION`, `GET_INSTANCE`. Verified 2026-08-12:

```
POST /v1/ciProducts
HTTP 403  The resource 'ciProducts' does not allow 'CREATE'.
```

So there is no API route around the wizard. Writes need the App Manager key `ASC6H3SL2D`; the
Developer key `S394C74APG` is refused with an empty `403` that reads like a malformed request.
Both Python scripts here are read-only by design — do deletions from a one-off script outside
either repository.

---

## Ruled out

- **Clearing `~/Library/Developer/Xcode/UserData/XcodeCloud/`** — the cache is empty *because* the
  list is.
- **Reading the App Store Connect UI as evidence** — it shows the onboarding splash, which is
  indistinguishable from having no product at all.
- **Repairing a seized product** — `ciProducts` takes no `PATCH`. The app link cannot be restored
  and the repository cannot be moved back. `DELETE` is the only lever.

## What is not affected by any of this

TestFlight builds live on the **app record**, not the product, and survive every deletion. And for
`no-spoilers`, Xcode Cloud is not on the shipping path at all: `scripts/ship.sh` delivers macOS
Developer ID / Homebrew, Mac App Store and iOS App Store, and an iOS App Store upload *is* a
TestFlight build. Xcode Cloud buys per-push builds and the automatic test gate — useful, not
load-bearing.

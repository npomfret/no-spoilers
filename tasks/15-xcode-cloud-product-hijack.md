# Task 15: Xcode Cloud "Create Workflow" hijacks a sibling project's product

**Status:** OPEN — diagnosed and cleared 2026-08-12 from the `super-funmax-music` side.
**This repo's Xcode Cloud product was deleted as part of the repair and has to be recreated
here.** Its workflow config is recorded below verbatim for exactly that purpose. Runs #1–#17
are gone; TestFlight builds are not.

**Do not run Integrate → Create Workflow while any product exists on this team.** The wizard
creates only from genuinely zero products; with one already there it seizes that one instead.
Every attempt destroys one more product. That is the whole finding.

> **This rule is the reverse of what this file said until 2026-08-12 14:53, and the old wording
> cost a third product.** It read *"do not run it while `GET /v1/ciProducts` returns an empty
> list"*, which reads the list count as the danger signal. The count cannot carry that meaning:
> it returns `0` both when the team truly has no products (creation works — that is how
> FunMaxMusic was recreated at 10:53) and when products exist but one is orphaned and has made
> the list unlistable (creation seizes). Those are opposite situations behind one number.
> Occurrence 3 below ran the wizard against a list of exactly `1`, listable and healthy, on the
> strength of that sentence.

## What task 14 saw, and what it missed

Task 14, *When Xcode will not let you create the workflow*, diagnosed this correctly and called
the outcome benign: retrying Create Workflow "made a **new** product and left the broken one in
place". It did not. It **took over the sibling project's product**, and the sibling stopped
building the same day.

On 2026-08-12 the same wizard was run from `super-funmax-music`, and it did the same thing in
reverse — this time to `1F3A0BBD-…`, the product task 14 created for this repo.

## The mechanism

Create Workflow does not reliably create. When the product list is unlistable, it grabs an
existing product record, **renames it, repoints its primary repository at the repo you ran it
from**, and then aborts with *"Workflow name already exists"* — because the record it seized
already contains a workflow called `Default`.

The abort happens *after* the rename and repoint, so a failed run is not a no-op. It leaves the
record with no `app` relationship (`GET /v1/ciProducts/{id}/app` → **HTTP 500**), and one
unlistable product makes the entire list unlistable, which sets up the next failure.

It is self-perpetuating: a broken list causes the hijack, and the hijack breaks the list.

## State as of 2026-08-12 11:50

Both products are now orphaned — no `app` relationship, both 500 — and the two projects have
swapped repositories. `GET /v1/ciProducts` returns `0` across eight checks over ten minutes,
while both products still resolve by id. Apple's system status reports Xcode Cloud healthy.

| | `EDF20772-21CF-443B-9337-464D47B3F61F` | `1F3A0BBD-DC5B-44FA-A767-65B3E14A433B` |
|---|---|---|
| created | 2026-08-08 (was FunMaxMusic's) | 2026-08-10 (was this repo's) |
| name now | `NoSpoilersApp` | `FunMaxMusic` |
| `app` relationship | gone, 500 | gone, 500 |
| primary repository | `no-spoilers` | `super-funmax-music` |
| workflow | `6229CF74-…` builds **FunMaxMusic** | `6EE7E8AE-…` builds **NoSpoilersApp** |
| last run | #28, 2026-08-09 | #17, 2026-08-10 |

Each product is attached to one repo and contains a workflow that builds the *other*. Both
workflows are still `enabled: true` and correctly configured in themselves — neither was edited.
The trigger follows the **product's** repository attachment, not the workflow's, which is why
`super-funmax-music` has built nothing since 2026-08-09 despite a workflow that is entirely valid.

**This repo is now in that same state**, and run #17 on 2026-08-10 is likely its last.

## Recovery material, before anything is deleted

`ciProducts` has no `PATCH`. The app link and the repository attachment cannot be repaired over
the API, so the only lever is `DELETE`, which takes the workflow and its run history with it.
TestFlight builds are unaffected — they live on the app record, not the product.

`6EE7E8AE-…` — this repo's workflow, currently inside the product named `FunMaxMusic`:

```
repository        npomfret/no-spoilers  (b36f1212-d272-4b37-9ba0-50c3277fd1f2)
containerFilePath NoSpoilers/NoSpoilers.xcodeproj
branch            main, autoCancel true
action 1  ARCHIVE  scheme NoSpoilersApp, IOS, APP_STORE_ELIGIBLE, isRequiredToPass true
```

`6229CF74-…` — FunMaxMusic's workflow, unchanged since 2026-08-09, recorded in task 14 and
re-verified today:

```
repository        npomfret/super-funmax-music  (3706b1f0-bfe2-472b-b936-b24b6043d789)
containerFilePath apple/FunMaxMusic/FunMaxMusic.xcodeproj
branch            main, autoCancel true
action 1  TEST     scheme FunMaxMusic, IOS, SPECIFIC_TEST_PLANS "UnitTests", isRequiredToPass true
action 2  ARCHIVE  scheme FunMaxMusic, IOS, APP_STORE_ELIGIBLE, isRequiredToPass true
```

## What was done, 2026-08-12 ~11:55

Both orphans were deleted with the App Manager key (`ASC_ADMIN_KEY_ID`), each returning
`HTTP 204`, and both then confirmed `404`. `GET /v1/ciProducts` now returns an empty list with
no unlistable record left in it.

```
DELETE /v1/ciProducts/EDF20772-…  -> 204   (FunMaxMusic's original)
DELETE /v1/ciProducts/1F3A0BBD-…  -> 204   (this repo's)
```

The write was made from a one-off script outside either repository. `app_store_connect.py` is
read-only by design and stayed that way.

**What this repo has to do:** recreate its product with Integrate → Create Workflow, rebuild
`Default` from the config recorded above, and **check `GET /v1/ciProducts` is non-empty
immediately afterwards**. If it reports zero while the product resolves by id, the new product
has landed without an `app` relationship and the fault has recurred — stop there rather than
retrying the wizard, because retrying is what hijacks the sibling.

Order matters: `super-funmax-music` is being recreated first, so confirm the list shows it
before creating this one.

## FunMaxMusic's restore baseline, taken 2026-08-12 12:0x

Recorded from this repo because this repo is the one about to run the wizard, and the wizard's
victim is the one project that will not notice. If the fault recurs, `CADFB659-…` is what has to
come back. Verified healthy at the time of recording: `/app` → `200`, and `scripts/ci_health.py`
→ `PASS`.

```
product           CADFB659-EC1D-48C9-9B34-EB2A225D6BD3  "FunMaxMusic", created 2026-08-12T10:53:48Z
app               6770023782  pomocorp.FunMaxMusic
repository        npomfret/super-funmax-music  (3706b1f0-bfe2-472b-b936-b24b6043d789)
workflow          EFDA9C91-8FBA-4A35-A58D-DA4135077DBE  "Default", enabled, clean, not locked
containerFilePath apple/FunMaxMusic/FunMaxMusic.xcodeproj
branch            main (exact, not prefix), autoCancel true, no file/folder rule
pull requests     no start condition
action 1  TEST     "UnitTests - iOS", scheme FunMaxMusic, IOS, isRequiredToPass true
                   SPECIFIC_TEST_PLANS "UnitTests", Recommended iPhones / iOS 26.5 simulator
action 2  ARCHIVE  "Archive - iOS", scheme FunMaxMusic, IOS, APP_STORE_ELIGIBLE,
                   isRequiredToPass true
```

Run history restarted at #1 — the recreation lost #1–#28, the same way this repo lost #1–#17. As
of 13:0x it holds run #1 (`MANUAL`, `SUCCEEDED`) and run #2 (`GIT_REF_CHANGE`, **`FAILED`**). The
failure is in that project's own build, not interference from here: this repo has no Xcode Cloud
product at all right now, so it owns nothing that could reach theirs.

## Guarding against a third occurrence

`scripts/ci_health.py` checks the invariant in both directions, which is the part no other tool
looks at:

- no product of ours may be attached to another project's repository
- **no product of theirs may be attached to ours**

The second is the one that costs somebody else four days. A hijack is invisible from the victim's
side — their workflow stays valid and enabled, and only the product's repository attachment
moves — so nothing on their end reports it.

`scripts/testflight_distribute.py` no longer holds a recorded product id. It finds the product by
**the app it builds, never by name**: after a hijack the record named `NoSpoilersApp` was the
sibling's and the record named `FunMaxMusic` was this repo's, so name-matching would have pointed
this repo's tooling straight at another project's product. `app` is the field the fault strips
rather than forges, so a seized record matches nothing instead of matching wrongly. Both
behaviours are replayed against this exact state in `appstore_status.py --selftest` and
`ci_health.py --selftest`.

## Recreating it worked — with one caveat worth knowing before you try

`super-funmax-music` recreated its product cleanly once both orphans were gone. Xcode was quit
and reopened first, so it re-read a list that was no longer poisoned.

```
product   CADFB659-…  created 2026-08-12T10:53Z
app link  6770023782  pomocorp.FunMaxMusic     <- resolves, no 500
repo      super-funmax-music
workflow  EFDA9C91-…  Default, enabled
          TEST     scheme FunMaxMusic, testPlanName "UnitTests", Recommended iPhones
          ARCHIVE  scheme FunMaxMusic, APP_STORE_ELIGIBLE
```

`GET /v1/ciProducts` reports **1**, not 0. That is the check that matters — run it immediately
after creating yours.

**The caveat: the first push after recreation triggers nothing.** Eight minutes of polling
produced no run, on a workflow that was enabled, unlocked, correctly branch-conditioned on
`main`, and whose repository Apple could plainly see (`gitReferences` resolved `refs/heads/main`).

`POST /v1/ciBuildRuns` with the workflow relationship started run #1 immediately
(`startReason: MANUAL`), and it completed `SUCCEEDED` — checkout, `UnitTests`, archive, and an
upload that reached TestFlight `VALID`. **The next push then triggered run #2 on its own**,
`startReason: GIT_REF_CHANGE`. The trigger arrives late, not never.

So if your recreated product ignores the first push, that is expected. Start the run over the
API and let the following push prove the webhook. Do **not** go back to the wizard to "fix" it —
that is the hijack path, and it is what cost two products.

## Occurrence 3, 2026-08-12 14:53 — the second-product question, answered

This repo ran Create Workflow with the list reporting exactly `1`: FunMaxMusic's recreated
product, listable, `/app` resolving `200`, `ci_health.py` `PASS` minutes earlier. It seized that
product. Same signature, no variation:

```
CADFB659  created 10:53:48Z as FunMaxMusic's
  name         FunMaxMusic          ->  NoSpoilersApp
  repository   super-funmax-music   ->  no-spoilers
  app          6770023782           ->  stripped, GET .../app -> HTTP 500
  workflow     EFDA9C91 "Default", unchanged, still apple/FunMaxMusic/FunMaxMusic.xcodeproj
  runs         1-5, last 13:45, runs 3/4/5 SUCCEEDED — a working product, taken mid-life
```

`GET /v1/ciProducts` went `1` -> `0` at the moment of the abort. The two products deleted at
11:55 stayed deleted; nothing was resurrected.

**So two products cannot be brought into being on this team by this wizard.** Every creation that
has ever worked here started from genuinely zero: FunMaxMusic's at 10:53, and task 14's original.
Every creation attempted with one product already present has seized it instead — three for
three, in both directions, now including a case where the list was in perfect health. The list
being unlistable is a *consequence* of the seizure, never its cause.

### The likelier mechanism, and the cheap test

The error is *"Workflow name already exists"*, and it is probably literal. Every product created
here gets a workflow named `Default`, because that is what the wizard names it. If workflow names
collide team-wide rather than per-product, then the second creation is refused on the name — and
the refusal happens *after* the rename and repoint, which is the whole fault. That fits all three
occurrences and the two successes without needing "second products are impossible" to be true.

It predicts a fix that costs nothing to try: **rename the surviving product's workflow off
`Default` before running the wizard again.** `PATCH /v1/ciWorkflows/{id}` is the lever, and unlike
`ciProducts` that resource does accept writes.

Whoever creates second bears the risk if the prediction is wrong, so the order should be: delete
the seized record, let one project create from zero, rename its workflow immediately, and only
then let the second project run its wizard. If the second one still seizes, the name theory is
dead, two products genuinely cannot coexist, and that is the report to Apple — with the `500` on
`GET /v1/ciProducts/{id}/app` as the symptom, since it is unambiguous and reproducible.

### Until it is resolved, do not push to `main` here

The seized product is attached to `no-spoilers`, and the trigger follows the product's repository
attachment. A push to this repo can now start a run that checks out this repo and tries to build
`apple/FunMaxMusic/FunMaxMusic.xcodeproj`. It fails, and it fails in the other project's run
history.

Two things task 14 already ruled out and that remain ruled out: clearing
`~/Library/Developer/Xcode/UserData/XcodeCloud/` (the cache is empty *because* the list is), and
reading the App Store Connect UI as evidence — it shows the onboarding splash, which is
indistinguishable from having no product at all.

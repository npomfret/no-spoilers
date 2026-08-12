# Task 15: Xcode Cloud "Create Workflow" hijacks a sibling project's product

**Status:** OPEN — diagnosed and cleared 2026-08-12 from the `super-funmax-music` side.
**This repo's Xcode Cloud product was deleted as part of the repair and has to be recreated
here.** Its workflow config is recorded below verbatim for exactly that purpose. Runs #1–#17
are gone; TestFlight builds are not.

**Do not run Integrate → Create Workflow while `GET /v1/ciProducts` returns an empty list.**
Every attempt destroys one more product. That is the whole finding.

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

**The caveat: a push to `main` did not trigger a run.** Two pushes and roughly eight minutes of
polling produced nothing, on a workflow that was enabled, unlocked, correctly branch-conditioned
on `main`, and whose repository Apple could plainly see (`gitReferences` resolved `refs/heads/main`).

`POST /v1/ciBuildRuns` with the workflow relationship started run #1 immediately
(`startReason: MANUAL`), and it completed `SUCCEEDED` — checkout, `UnitTests`, archive, and an
upload that reached TestFlight `VALID`. So the workflow is sound and the *trigger* is the part
that did not come back with it. Whether it wires itself up after the first manual run is still
unknown; that is the next thing to watch here.

If your recreated product behaves the same, do not retry the wizard to "fix" it — that is the
hijack path. Start a run over the API instead.

## Still untested

Whether two products can coexist in this team at all. Every observation so far involves exactly
one surviving record, and both hijacks happened while a second was being created. If the fault
recurs on the second creation, that is the thing to report to Apple — with the 500 on
`GET /v1/ciProducts/{id}/app` as the concrete symptom, since it is unambiguous and reproducible.

Two things task 14 already ruled out and that remain ruled out: clearing
`~/Library/Developer/Xcode/UserData/XcodeCloud/` (the cache is empty *because* the list is), and
reading the App Store Connect UI as evidence — it shows the onboarding splash, which is
indistinguishable from having no product at all.

# Task 15: Xcode Cloud "Create Workflow" hijacks a sibling project's product

**Status:** OPEN — this repo is working again as of 2026-08-12 15:31, and the fault is not
resolved. Product `F6A2F0EB` was created into a proven-empty team and has delivered
`1.1.0 build 1` to TestFlight, so nothing here blocks this repo. What remains open is the fault
itself: `super-funmax-music` still has no product, and its recreation is the live test of the
workflow-name theory below. **If that attempt seizes `F6A2F0EB`, the theory is dead and this
becomes a bug report to Apple** rather than a procedure. Three products have been lost so far.
Runs #1–#17 and FunMaxMusic's #1–#5 are gone; TestFlight builds never were.

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

> **The causal claim in that paragraph is wrong — corrected 2026-08-12 16:0x.** Starting a run by
> hand does not prime the trigger. This repo's recreated product was manually run at 15:52, it
> succeeded, and the push at 15:58 still produced nothing after eight minutes of polling — four
> pushes now with no `GIT_REF_CHANGE` at all. `lastAccessedDate` on the repository record reads
> `14:53:00Z`, which is run #2's own checkout: Apple has not looked at the repo in response to any
> push.
>
> What the FunMaxMusic timings actually show is a delay, not a cause. Its run #1 (`MANUAL`) was
> 11:42 and its run #2 (`GIT_REF_CHANGE`) was 13:01 — 79 minutes, with the product created at
> 10:53. The manual run happened to fall inside that window rather than opening it.
>
> **"An hour or more" was too confident, on one sample — corrected again at 17:12.** Their next
> product, created 15:39, took its first `GIT_REF_CHANGE` at 16:04: **25 minutes**. Two samples,
> 25 and 79 minutes, and this repo's own product never triggered at all across four pushes in the
> 50 minutes it survived. So: the connection goes live some tens of minutes after creation, the
> spread is wide, and no number here is a rule.
>
> Practical consequence: after recreating, expect pushes to be ignored for a while, use
> `POST /v1/ciBuildRuns` for anything urgent, and do not go near the wizard — a dead trigger looks
> exactly like a misconfigured workflow, and "fix it by recreating" is the path that has destroyed
> three products.

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

### This repo's restore baseline, taken 2026-08-12 15:1x

Recorded before `super-funmax-music` runs its wizard, because that attempt is the experiment and
this product is what it would take. Created from a genuinely empty team — `404` on the seized id
*and* `total 0` — which is the only state that has ever produced a product rather than a theft.

```
product           F6A2F0EB-1577-4C80-B65B-1A5528247E1D  "NoSpoilersApp", created 2026-08-12T14:08:21Z
app               6761343835  pomocorp.NoSpoilers.NoSpoilersMac
repository        npomfret/no-spoilers  (b36f1212-d272-4b37-9ba0-50c3277fd1f2)
workflow          52C80043-0E46-4EE1-A1D3-2D48736B622D  "NoSpoilers iOS", enabled, clean, not locked
containerFilePath NoSpoilers/NoSpoilers.xcodeproj
branch            main (exact, not prefix), autoCancel true, no file/folder rule
pull requests     no start condition; no tag or schedule condition either
action 1  ARCHIVE  "Archive - iOS", scheme NoSpoilersApp, IOS, APP_STORE_ELIGIBLE,
                   isRequiredToPass true
```

**The workflow is deliberately not called `Default`.** If the name theory holds, that name is the
contended resource, and leaving it unoccupied is what lets the other project create.

The wizard also added a second action, `Archive - macOS` on scheme `NoSpoilers`, which was removed
in Xcode's workflow editor before any run. It would have uploaded a macOS build numbered from
`CI_BUILD_NUMBER` on every push — a fourth delivery path into the band `release.sh` reserves from
10000, and a 1.1.0 macOS train nobody asked for while 1.0.21 is live. Check for it on any future
recreation; the wizard adds it from the schemes it finds, not from anything recorded here.

## The experiment, set up 2026-08-13 08:5x

FunMaxMusic's product was deleted first, by the owner's decision, so that **this repo is the one
exposed**. The wizard seizes the product that already exists, so the first mover is the victim and
the second merely gets an error — the reverse of the ordering used on 2026-08-12, and the reason
that day cost FunMaxMusic two products.

This repo's product, created into a team empty by id (both prior ids `404`):

```
product           9C40B27D-5C9B-4AB2-A9A2-6B97616BAA3F  "NoSpoilersApp", created 2026-08-13
app               6761343835  pomocorp.NoSpoilers.NoSpoilersMac
repository        npomfret/no-spoilers  (b36f1212-d272-4b37-9ba0-50c3277fd1f2)
workflow          7A43B70B-3311-4954-A625-AB82333B6503  "NoSpoilers iOS", enabled, not locked
containerFilePath NoSpoilers/NoSpoilers.xcodeproj
branch            main (exact, not prefix), autoCancel true, no file/folder rule
action 1  ARCHIVE  "Archive - iOS", scheme NoSpoilersApp, IOS, APP_STORE_ELIGIBLE,
                   isRequiredToPass true
runs              none — deliberately. It is left empty until FunMaxMusic has created,
                  because zero history is what makes it cheap to lose.
```

**It is deliberately not named `Default`.** FunMaxMusic now creates second, into a team where the
only workflow is called `NoSpoilers iOS`. If creation succeeds, the collision is the fault and two
projects coexist by naming workflows apart. If it seizes this product, the theory is dead, two
products cannot share this team, and the report to Apple is the `500` on
`GET /v1/ciProducts/{id}/app`.

Two UI notes for whoever runs the wizard next, since the recorded settings did not match what
Xcode actually shows:

- There is no "TestFlight" option. It is **Distribution Preparation: App Store**, which is what
  produces `APP_STORE_ELIGIBLE`. The default is `None`, which archives and uploads nothing.
- "Exact match" is not a control. *Custom Branches* with `main` typed in is exact; the API records
  it as `isPrefix: false`.
- The wizard again fitted an `Archive - macOS` action nobody asked for, built from the schemes it
  found. Deleted in the editor before saving. Expect it every time.

## FunMaxMusic's restore baseline, taken 2026-08-12 17:2x

Recorded from this repo because this repo is about to run the wizard, and the wizard's victim is
the one project that will not notice. Verified resolving at the time of recording.

```
product           28472948-8E80-4EF5-BEF7-7D9A75871315  "FunMaxMusic", created 2026-08-12T15:39:17Z
app               6770023782
repository        npomfret/super-funmax-music  (3706b1f0-bfe2-472b-b936-b24b6043d789)
workflow          91354094-734F-4096-A93A-17A502322EE5  "Default", enabled, clean, not locked
containerFilePath apple/FunMaxMusic/FunMaxMusic.xcodeproj
branch            main (exact, not prefix), autoCancel true, no file/folder rule
pull requests     no start condition; no tag or schedule condition
action 1  TEST     "UnitTests - iOS", scheme FunMaxMusic, IOS, test plan "UnitTests",
                   isRequiredToPass true
action 2  ARCHIVE  "Archive - iOS", scheme FunMaxMusic, IOS, APP_STORE_ELIGIBLE,
                   isRequiredToPass true
runs at capture   #1 MANUAL SUCCEEDED 15:51, #2 GIT_REF_CHANGE CANCELED 16:04,
                  #3 GIT_REF_CHANGE 16:11
```

**Their workflow is named `Default`. Ours must not be.** That is the entire experiment.

## The list is a cache, and it has lied in both directions

`GET /v1/ciProducts` is not evidence of anything on its own:

- **2026-08-12 11:50** — returned `0` across eight checks over ten minutes while two products
  still resolved by id.
- **2026-08-12 15:30–17:12** — kept naming `F6A2F0EB` for over ninety minutes after a `DELETE`
  that answered `204`, app relationship and all, while every by-id call returned `404`.

**Only the by-id `404` is honest.** `ci_health.py` now re-fetches every listed id and excludes
non-resolving records as ghosts, because counting one is precisely how this repo concluded that
two products had coexisted on a team that has never held two.

## Occurrence 4 was not the fault — it was a deliberate deletion

`F6A2F0EB` was deleted from the `super-funmax-music` side at ~15:30Z with its configuration
recorded first, and their wizard ran at 15:39:17Z into a team that was empty *by id* though the
list still showed ours. Their commits `1e44b3d` (15:30:14Z) and `938374f` (15:41:15Z) record both
halves, the second explicitly noting *"a stale list is not an occupied team"*.

So no new failure mode: no rename, no repoint, app link intact in the listing, `404` on every
by-id call. A completed `DELETE` plus a stale list explains every symptom.

**What this costs us is the experiment.** Their product carries the workflow name `Default`, and
ours had been deliberately named `NoSpoilers iOS` so that the two could not collide — but ours was
gone before their wizard started, so nothing was tested. **Two products have still never existed
on this team at the same time, and the workflow-name theory is exactly as unproven as it was this
morning.** Every successful creation, all four of them, started from a team empty by id.

That leaves one decisive experiment: create a second product, with a workflow named something
other than `Default`, while a real one resolves. If it creates, the name is the contended
resource and both projects can coexist by naming their workflows apart. If it seizes, two products
cannot coexist on this team at all, and the bug report to Apple is the `500` on
`GET /v1/ciProducts/{id}/app`. The cost of it failing is one recreation from empty, which is a
procedure that now works reliably — but the product it would take is the *other* project's, so it
is not a decision either repo can take alone.

### Cleared, 2026-08-12 15:0x

While the seizure stood, a push here was unsafe: the trigger follows the product's repository
attachment, so a push to `no-spoilers` would have started a run that checked out this repo and
tried to build `apple/FunMaxMusic/FunMaxMusic.xcodeproj`, failing in the other project's run
history. `DELETE` returned `204`, the id then read `404` and the list `0` — both, which is what
distinguishes an empty team from an unlistable one — and the product above was created into that
emptiness. FunMaxMusic's runs #1–#5 went with it; that record was unrepairable either way, since
`ciProducts` takes no `PATCH` and its `app` relationship was already stripped.

Two things task 14 already ruled out and that remain ruled out: clearing
`~/Library/Developer/Xcode/UserData/XcodeCloud/` (the cache is empty *because* the list is), and
reading the App Store Connect UI as evidence — it shows the onboarding splash, which is
indistinguishable from having no product at all.

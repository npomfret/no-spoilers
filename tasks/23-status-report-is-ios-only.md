# Task 23: the status report cannot see Mac builds

**Status: OPEN, deferred on purpose. Carried out of task 17 when it was closed on 2026-08-15;
the user's decision on 2026-08-14 was "not now, record it".**

`scripts/appstore_status.py` has `TESTFLIGHT_PLATFORM = "IOS"` and its TestFlight section covers
that platform only.

## Why this became a defect on 2026-08-14

It was accurate while it was written: the Mac app had no TestFlight story at all. Since the macOS
`ARCHIVE` action went into the Xcode Cloud workflow, **every push uploads a Mac build too**, and
handing a build to testers is a manual command on both platforms.

So the failure mode now exists and the report is blind to exactly it: **a stranded Mac build and no
Mac build print identically.** The build uploads, processes, goes `VALID`, reaches no group, and the
report says nothing at all — which is the same thing it says when macOS was never archived. Every
other signal reads as success, which is the whole reason this report exists.

Measured on macOS 1.1.1 build 15, immediately after run 15: `processingState VALID`,
`include=betaGroups` → `included: []`.

## What it takes

Not a constant swap. `TESTFLIGHT_PLATFORM` is read by `distribution`, `attention`, `render` and the
fixtures, and the output is a single `TESTFLIGHT (IOS)` block.

- **Hoist the tester-group fetch out of `distribution` first.** Beta groups are app-wide, not
  per-platform, so a naive loop over platforms would fetch them twice and print them twice. This is
  the readiness refactor; do it before threading anything.
- Then thread the platform through `distribution`, `attention` and `render`, and through the
  fixtures that pin them.
- `DISTRIBUTION_WALK` is per-platform work: it is one `GET /v1/builds/{id}?include=betaGroups` per
  undistributed build, so covering two platforms doubles the requests. Ten each is still cheap.

## Constraints that must survive it

- **The script issues `GET`s and nothing else**, on the Developer-level key `S394C74APG`. That split
  is what makes it safe to run at any time. Do not let a "fix it while you are there" creep in.
- **Being behind is never a warning.** Delivery is a manual command, so the newest build reaches
  nobody after every push — on both platforms now, so a naive port would double a false alarm that
  was correctly suppressed. Only being able to install *nothing at all* goes under NEEDS YOU.
- **`testflight_distribute.py` has a selftest guard that pins `PLATFORMS[DEFAULT_PLATFORM]` to
  `asc.TESTFLIGHT_PLATFORM`**, so the command's default and the report's coverage cannot silently
  diverge. If `TESTFLIGHT_PLATFORM` stops being a single value, that guard has to be replaced rather
  than deleted — it is guarding against the report confirming a delivery on the platform nobody
  delivered to.
- **Apple spells this platform two ways** and both appear in this repo: `MAC_OS` in
  `filter[preReleaseVersion.platform]` on `/v1/builds`, `MACOS` as the Xcode Cloud `CiPlatform`.
  Only one is ever right in a given call.

## Verification

- [ ] A stranded Mac build is reported, and reads differently from no Mac build existing
- [ ] Tester groups are fetched once and printed once
- [ ] Being behind on either platform still leaves NEEDS YOU empty and the exit code 0
- [ ] `scripts/appstore_status.py --selftest` and `scripts/testflight_distribute.py --selftest` pass
      (60 and 27 cases at the time of writing)

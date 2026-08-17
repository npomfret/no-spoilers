# Testing Guide

Canonical testing and verification policy for this repo.

## Rules

- Never claim tests passed unless they were executed to completion.
- Run the smallest meaningful verification for the changed behavior first.
- Distinguish compile/build confidence from behavior-risk confidence.
- After a bug fix or behavior change, rerun the relevant verification before handoff.
- Prefer deterministic tests and explicit evidence over broad “should be fine” claims.
- If the repo standardizes wrappers for tests, use them instead of ad-hoc raw commands.

## Current state

- Use `scripts/verify-core-tests.sh` for shared package behavior tests. It runs `swift test` against `NoSpoilersCore` with repo-local HOME/Foundation home, scratch, and module-cache paths, and disables SwiftPM's nested sandbox for compatibility with Claude's execution sandbox.
- For app, widget, or macOS behavior changes without dedicated UI tests, pair the smallest relevant build wrapper from `docs/guides/building.md` with focused manual or code-review evidence.
- If a new test surface is added, create or update a repo-owned wrapper before treating the command as canonical.

## Watching a widget timeline reload

Every date decision the widget makes is unit-tested in `TimelinePlannerTests`, so the only thing
left to watch on a device is whether WidgetKit honours the plan. That is the hardest behaviour in
this product to observe — the app is not running, nothing is attached, and a widget that never
reloaded looks exactly like one with nothing new to show. Two things about it cost a morning of
wrongly-scored experiments on 2026-08-17.

- **A clock shift cannot test the reload.** chronod schedules on elapsed time and ignores
  wall-clock jumps, so moving the host clock past a live reload date produces nothing — twice —
  while the archived entries keep advancing correctly. Entry *selection* follows the wall clock;
  timeline *regeneration* does not. Shifting the clock also breaks `sudo` mid-run, because sudo
  validates its cached credential against the wall clock: authenticate a root helper **before** the
  first shift.
- **Force the truncation branch to get a reload date you can sit and wait for.** A fixture of 40
  sessions at 10-second spacing produces ~89 boundaries against `maxTimelineEntries`, so the plan
  truncates and the reload date becomes the 24th boundary — about nine minutes out instead of 48
  hours. Seconds before it falls due, swap the App Group cache for a weekend that appears in **no**
  archived entry. If the widget draws that weekend, the only thing that can have drawn it is a fresh
  `getTimeline` that re-read the cache.
- **Assert that a build happened before concluding anything about a reload**, and prefer the screen
  to the log when they disagree. The two mis-scored experiments both rested on an absent log line
  while the widget was visibly doing the right thing; `LogChannel` does not offer `.info` any more,
  which is what stops that particular version of it recurring.

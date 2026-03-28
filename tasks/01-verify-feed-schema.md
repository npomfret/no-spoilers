# Task 01: Verify Feed Schema

**Status:** DONE
**Depends on:** nothing
**Effort:** ~30 minutes

## Goal

Confirm that the f1calendar.com JSON feed is structurally free of race result data, and document the exact field names used for session types.

This is the prerequisite gate for `tasks/02-swift-package-setup.md`. The `SessionKind` enum raw values and the `Session` decoder cannot be written until this is done.

## Feed

```
https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/2026.json
```

## Spoiler Safety — VERIFIED CLEAN

No spoiler keys (`results`, `winner`, `position`, `points`, `laps`, `grid`) exist at any nesting level. Feed is schedule-only.

## Confirmed JSON Structure

Top-level:
```json
{
  "races": [ ...RaceObject... ]
}
```

Race object keys: `name`, `location`, `latitude`, `longitude`, `round`, `slug`, `localeKey`, `sessions`

- `name` is the short form — e.g., `"Australian"`, `"Chinese"` (not "Australian Grand Prix")
- No `circuitName` field in the feed
- `sessions` is a flat object of `sessionKey → ISO8601 UTC string` (start time only — no end times)

## Session Key Mapping — CONFIRMED

Two corrections from the original expected mapping:

| SessionKind case | Feed key | Note |
|---|---|---|
| `freePractice1` | `fp1` | confirmed |
| `freePractice2` | `fp2` | confirmed |
| `freePractice3` | `fp3` | standard weekends only |
| `qualifying` | `qualifying` | confirmed |
| `sprintQualifying` | `sprintQualifying` | **camelCase — not `sprint_qualifying`** |
| `sprint` | `sprint` | confirmed |
| `race` | `gp` | **key is `gp`, not `race`** |

## Session Structure by Weekend Type

**Standard weekend** (fp1, fp2, fp3, qualifying, gp):
- Rounds 1, 3, 6, 7, 8, 10, 11, 13, 14, 15, 17, 18, 19, 20, 21, 22

**Sprint weekend** (fp1, sprintQualifying, sprint, qualifying, gp):
- Rounds 2, 4, 5, 9, 12, 16

## Date Format

All timestamps: ISO 8601 UTC — `"2026-03-06T01:30:00Z"`

`JSONDecoder.dateDecodingStrategy = .iso8601` handles these correctly.

## Critical: No End Times in Feed

The feed provides **start times only**. `endsAt` must be derived from hardcoded session durations.

Suggested defaults:
- `fp1`, `fp2`, `fp3`: 60 minutes
- `qualifying`: 60 minutes
- `sprintQualifying`: 45 minutes
- `sprint`: 30 minutes
- `gp`: 120 minutes (conservative — covers most races including overruns)

The `Session` domain model can store `endsAt` as a computed property: `startsAt + kind.defaultDuration`.

## Domain Model Corrections (vs. original design doc)

1. `SessionKind.race` raw value must be `"gp"` (not `"race"`)
2. `SessionKind.sprintQualifying` raw value must be `"sprintQualifying"` (not `"sprint_qualifying"`)
3. `Session.circuitName` — no such field in feed; remove from model or derive from `slug`
4. `Session.endsAt` — not in feed; must be computed from `startsAt + kind.defaultDuration`
5. `grandPrixName` must be constructed: `"\(race.name) Grand Prix"` (feed gives short form)

## Bundled JSON

No bundled JSON — the calendar changes mid-season (cancellations, reschedules). The app always fetches live; stale cache is the fallback; blank state is acceptable when neither is available. See task 03.

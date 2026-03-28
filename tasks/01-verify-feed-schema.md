# Task 01: Verify Feed Schema

**Status:** TODO (blocking — do this before any other task)
**Effort:** ~30 minutes

## Goal

Confirm that the f1calendar.com JSON feed is structurally free of race result data, and document the exact field names used for session types.

This is the prerequisite gate for `tasks/02-swift-package-setup.md`. The `SessionKind` enum raw values and the `Session` decoder cannot be written until this is done.

## Steps

1. Open the feed in a browser or fetch it:
   ```
   https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/2026.json
   ```

2. Confirm the feed contains **none** of these keys at any nesting level:
   - `results`
   - `winner`
   - `position`
   - `points`
   - `laps`
   - `grid`
   (Note: `status` is acceptable if values are schedule states like `"scheduled"` or `"cancelled"`, not race outcomes.)

3. Note the exact string values used for each session type. Expected mapping to verify:

   | SessionKind case | Expected raw value | Confirmed? |
   |---|---|---|
   | `freePractice1` | `fp1` | [ ] |
   | `freePractice2` | `fp2` | [ ] |
   | `freePractice3` | `fp3` | [ ] |
   | `qualifying` | `qualifying` | [ ] |
   | `sprintQualifying` | `sprint_qualifying` | [ ] |
   | `sprint` | `sprint` | [ ] |
   | `race` | `race` | [ ] |

4. Note the top-level JSON structure — how is a race weekend represented? How are sessions nested under a round?

5. Update this task with the confirmed schema and mark as DONE.

## Outcome

- Spoiler-safety guarantee is verified at the source level
- `SessionKind.rawValue` mapping is confirmed
- `Session` decoder can be implemented in task 02

## Notes

If the feed schema differs significantly from the expected shape, stop and revise the `Session` domain model before proceeding. Do not work around a schema mismatch — get the model right.

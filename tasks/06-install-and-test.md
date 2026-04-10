# Task 06: Install on Real Devices + Race Weekend Test

**Status:** TODO
**Depends on:** Tasks 03, 04, 05 complete
**Effort:** ~1 hour setup + one race weekend of real use

## Goal

Install on your own iPhone and Mac and use it through a real race weekend. This is the only acceptance test that matters for v1.

## Install

```bash
# iOS — connect iPhone, select as run destination in Xcode
# Build NoSpoilersApp scheme — widget installs alongside

# macOS — run NoSpoilers scheme
# Or: Archive → Export → Distribute App → Copy App
```

Add the widget to your iPhone home screen:
1. Long-press home screen
2. Tap "+"
3. Search "No Spoilers"
4. Add `.systemMedium` size

## Verification Checklist

Before the race weekend:
- [ ] Widget appears on home screen
- [ ] Correct sessions listed for the upcoming weekend
- [ ] Times shown in your local timezone
- [ ] macOS menu bar label shows the next session correctly
- [ ] Open the app — no result data visible anywhere

During the race weekend:
- [ ] Widget updates itself between sessions (no manual refresh)
- [ ] "Watchable" label appears after a session ends
- [ ] Countdown updates correctly for the next session
- [ ] macOS popover shows the correct current state

After the race weekend:
- [ ] All sessions show as "watchable"
- [ ] Off-season or next-weekend state appears when appropriate

## The Core Test

Can you check when the race is without seeing who won?

If yes: the product works.
If no: find what leaked and fix it before anything else.

## Known Limitation

The widget may show slightly stale times if the iOS host app has not been launched in days and the feed has been updated (e.g., F1 reschedules an event). The bundled JSON ensures no blank state. Update the bundled JSON manually if a reschedule occurs mid-season.

## Notes

If anything feels wrong during the race weekend, file it in `tasks/` as a new task with exact repro steps. Do not fix from memory after the fact.

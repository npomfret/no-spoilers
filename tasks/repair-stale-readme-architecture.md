# Repair stale README architecture

## The issue

`README.md` describes a bundled season JSON fallback and shows a fixed annual feed URL in its data
flow. The current implementation has no bundled season JSON: `ScheduleStore` retains or reloads the
cache when refresh fails, while `ScheduleFetcher` reads `config.json` and derives the calendar year
from `calendarOutputYear`. The README therefore teaches contributors an implementation that no
longer exists and could misdirect future fallback or rollover work.

This was discovered during the Claude Code environment audit. It is deliberately not folded into
that control-plane change because the README needs its own source-backed review for other stale
architecture claims before it is rewritten.

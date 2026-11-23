# Mac schedule departure board

The Mac popover should alternate each upcoming session's countdown with its local
start date and time. Flip timing text from top to bottom, one row at a time, without
moving the session name or changing the spoiler-free schedule contract.

## Scope and checked mechanisms

- Mac schedule: `WeekendPopoverView.sessionList`, `sessionRow`, `statusBadge` and
  the existing injected clock/visible lifetime. The menu bar title, next-weekend
  footer, iPhone and widgets keep their current behaviour.
- Shared row inventory: Mac `sessionRow`; iPhone `sessionCard` and `skeletonView`;
  widget `smallSessionRow` and `widgetSessionRow` (medium and large). All five source
  call sites supply a `Text?` detail. Generalise that existing detail slot to a
  `View?`, retaining its optionality and owning layout, rather than copying a row.
- `Strings.Schedule.sessionDateTime` already owns locale/time-zone formatting;
  extend it with a full-month presentation while preserving existing defaults.
- `SharedChrome.swift`, `Theme.Motion`, `DecemberDecorationView`, and searches for
  flip/rotation/alternation found no existing departure-board component or cycle.
  A sibling-workspace filename search found no applicable native component.
- Use one new reusable text component and an immutable, UI-independent cycle.
  Cadence and animation tokens remain in `Theme.Motion`. No per-row timers/tasks.

## Decisions and acceptance

- Mac only: five-second readable holds, half-second row staggering, brief flips.
  Reuse the popover's existing clock publisher at the stagger interval; reset on
  appearance or schedule change and stop publishing view state while hidden.
- Upcoming timing uses the full available detail line rather than competing with
  a trailing badge inside the 300pt popover. Other statuses retain dates and badges.
- Localized date order and 12/24-hour conventions come from Foundation. No new
  translatable phrases or languages are introduced.
- Reduce Motion shows both values statically. Accessibility exposes both values
  independently of the visual face; no changing countdown-only accessible label.
- Keep iPhone/widget rendering unchanged at the five inventoried call sites.
- Verify cycle boundaries and both sweep directions without real-time waits;
  verify full-date locale/time-zone behaviour; run canonical core and Mac checks
  serially with one worker, inspect rendered Mac layout, and obtain independent UI
  and spoiler-safety reviews before landing.

## Evidence and remaining work

Implementation and verification pending.

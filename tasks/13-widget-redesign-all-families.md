# Task 13: Redesign Widgets Across All System Families

**Status:** Planned
**Depends on:** Task 11 shared chrome, Task 12 widget freshness and style
**Priority:** High

## Goal

Redesign the widget family so every system size feels like the same No Spoilers product and uses the established shared style.

The redesign must:

- cover `systemSmall`, `systemMedium`, and `systemLarge`
- stay spoiler-safe and schedule-only
- preserve the current shared cache and WidgetKit timeline approach
- use the existing shared chrome and brand palette instead of introducing a widget-only visual system

## Approved Pattern

The approved shared boundaries today are:

- `BrandPalette` for all colours
- `NoSpoilersBackground`, `NoSpoilersCard`, `NoSpoilersWordmark`, `NoSpoilersRoundPill`, and `NoSpoilersStatusBadge` for shared visual language
- `RaceWeekendResolver` and `SessionResolver` for widget state selection
- `ScheduleCache` plus App Group shared container for cached widget-readable data
- WidgetKit timeline entries generated from meaningful date boundaries, not app-side polling

The widget should continue to converge toward these shared boundaries. Do not introduce a second styling or state-selection layer.

## Problem

The current widget supports `systemSmall`, `systemMedium`, and `systemLarge`, but the family system is still incomplete and too close to being one layout with minor row-count changes.

Current issues:

- family layouts are not yet defined as one cohesive system
- small, medium, and large are insufficiently differentiated by purpose
- widget-local spacing decisions need to be validated against the shared chrome so style does not drift
- the widget should feel visually aligned with the iOS app and macOS popover, using the same blush, ivory, smoke, mist-grey, restrained red, and status-colour rules

## Design Direction

Use the established No Spoilers visual language:

- warm ivory/blush atmospheric background
- translucent white cards with soft borders
- signal red only for key emphasis and live moments
- success green only for finished or safe-to-watch state
- upcoming blue only for future state
- smoke for primary text and quieter neutrals for supporting metadata

Do not introduce:

- a new palette
- a darker widget-only theme
- dense table-like schedule layouts
- mini-app layouts
- scrolling mental models

## Plan

1. Define a distinct content budget and hierarchy for each family instead of scaling one layout up and down.
2. Audit the current widget layout constants and determine which belong in shared chrome versus remaining family-local.
3. Refactor widget rendering around explicit family layouts with one shared header language and one shared session-row language.
4. Keep freshness driven by shared cache, timeline boundaries, and date-backed rendering rather than more aggressive reload behavior.
5. Add preview coverage for all three families so layout drift is visible during development.

### Family Content Strategy

#### Small

Purpose: one glanceable answer.

Show:

- current weekend header
- exactly one primary session row
- one primary state only: live, upcoming countdown, or recently finished

Rules:

- no multi-row list
- no next-weekend footer
- no overflow indicator
- if there is no active weekend, use the existing off-season or unavailable message-card pattern

#### Medium

Purpose: current weekend plus short supporting context.

Show:

- compact header
- up to two prioritized session rows
- optional next-weekend footer only if space remains cleanly

Rules:

- keep the layout single-column
- prioritize current or next actionable sessions over completed history
- footer must remain visually secondary

#### Large

Purpose: full weekend overview.

Show:

- expanded header
- main session stack for the active weekend
- optional overflow label only if the layout still cannot fit all sessions
- next-weekend footer separated clearly from the current-weekend stack

Rules:

- large must feel like an overview layout, not medium with one extra row
- session states should be scannable in one pass
- preserve clear breathing room between header, schedule, and footer

## Layout And Spacing Rules

- keep widget outer spacing aligned with system widget content margins
- preserve the shared widget card density as the baseline for corner radius, padding, fill, border, and shadow
- use family-specific spacing only when the shared density is not sufficient, and document each exception
- maintain legible compact text sizing consistent with the existing shared chrome
- prefer widget-safe shapes and backgrounds that match system geometry
- do not disable system widget margins unless the replacement spacing is explicit and necessary

## Public Interfaces And Types

Shared additions are allowed only if needed to prevent duplicated widget-only layout logic, for example:

- a widget family layout configuration type
- shared family-driven spacing or typography variants
- shared preview fixtures for widget entries

Do not add:

- a second widget state-selection layer
- a widget-only palette
- duplicated header or row primitives outside the shared chrome direction

## Acceptance Criteria

- the redesign is explicitly specified for `systemSmall`, `systemMedium`, and `systemLarge`
- each family has a distinct content budget and hierarchy
- the widget remains visibly aligned with the established app and popover style
- all colours continue to come from `BrandPalette`
- shared chrome primitives remain the baseline unless intentionally expanded in `NoSpoilersCore`
- freshness still comes from shared cache, timeline boundaries, and date-driven rendering
- no spoiler-bearing data or result-style affordances are introduced
- the implementation path is clear without inventing new product decisions for any family

## Non-Goals

- adding results, standings, headlines, or live timing
- adding a separate widget design system
- replacing the existing cache and timeline architecture
- broad app redesign outside the widget family work

## Verification

1. `swift test`
   Working directory: `NoSpoilersCore`

2. `xcodebuild -project NoSpoilers/NoSpoilers.xcodeproj -scheme NoSpoilersWidgetExtension -destination 'generic/platform=iOS' -derivedDataPath /tmp/no-spoilers-widget CODE_SIGNING_ALLOWED=NO build`

3. Add or update previews for:
   - `.systemSmall`
   - `.systemMedium`
   - `.systemLarge`

4. Manual review against `docs/brand.md` and the shared chrome in `NoSpoilersCore` to confirm there is no palette drift or widget-only style divergence.

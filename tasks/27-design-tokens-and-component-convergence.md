# Task 27: the app cannot be reskinned — colour is the only token that exists

**Status: OPEN. Review complete 2026-08-17, nothing implemented. The proposal in "Recommended
shape" introduces a new pattern family and needs approval before any of it is written.**

## The test this is measured against

> Change the accent colour, the type scale, the corner radii, the spacing rhythm, the motion, and
> the icon set — one edit each — and have the iOS app, the macOS popover, the menu bar label, and
> all four widget families follow.

Colour passes, mostly. Nothing else passes at all. Every other design decision is a numeric or
symbol literal typed at the call site, and the same component is written out two, three, or four
times in parallel with the copies already disagreeing.

Measured across `NoSpoilers/` and `NoSpoilersCore/Sources/` (excluding `research/`):

```
88  .font(…)          call sites, none referring to a shared scale
59  .padding(…)       call sites, 57 of them numeric literals
69  spacing: <int>    literals on VStack/HStack
21  .opacity(…)       literals
16  Divider()         with no shared rule about where a divider goes
11  .system(size:)    absolute point sizes, all in the macOS targets
 0  spacing, radius, typography, motion, or icon constants anywhere in the repo
```

For contrast: `docs/index.html` — the landing page — already has `--signal-red`, `--radius`,
`--card`, `--border`, `--mono` as CSS custom properties. **The website is better factored for a
reskin than the app is.**

## What is already right — do not rebuild these

1. **`BrandPalette`** (`NoSpoilersCore/Sources/NoSpoilersCore/BrandPalette.swift`) — one public enum,
   every colour, no target-local colour constants. This is the model the rest of the work should
   copy. It is also the only thing `docs/brand.md` specifies.
2. **`SharedChrome.swift`** — six shared components already crossing all three targets:
   `NoSpoilersBackground`, `NoSpoilersCard`, `NoSpoilersWordmark`, `NoSpoilersRoundPill`,
   `NoSpoilersStatusBadge`, `NoSpoilersMessageCard`. The boundary exists and works; it is just far
   too small a share of what is on screen.
3. **`NoSpoilersCardDensity`** (`SharedChrome.swift:3-73`) — regular/compact/widget, mapping to
   radius, padding, shadow, and fill opacity. **This is the correct idea and the seed of the whole
   task.** Its only flaws are that it is `internal`, that it feeds exactly one component, and that
   every other component re-expresses the same axis as a `compact: Bool` parameter.
4. **The `Strings.swift` rule** — four files, one per module, documented in
   `docs/guides/swift-patterns.md`. The rule is right and mostly followed; the problem below is
   duplication *between* the four, not text escaping them.
5. **`FlagImage`** — one shared component for the only image the UI draws from data.

## A. Tokens that do not exist

### A1. Spacing — nothing, anywhere

Every gap is a literal. The values in use are 0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 12, 14, 16, 20 — which
is not a scale, it is whatever looked right in the file being edited that day. `.padding(.horizontal,
16)` appears 12 times across four files with no shared name for "16".

`NoSpoilersCardDensity` centralises padding **for the card only**, and its values are unreachable
from outside `NoSpoilersCore` because the properties are `internal`.

### A2. Typography — nothing, and three incompatible idioms

All 88 `.font(…)` calls are inline, in three mutually incompatible styles:

- **semantic** — `.caption`, `.headline`, `.subheadline`, `.title2`
- **semantic + weight** — `.caption2.weight(.semibold)`, `.body.weight(.semibold)`
- **absolute points** — `.system(size: 13)`, `.system(size: 12, weight: .medium)`,
  `.system(size: 11)`, all in `NoSpoilersMac/`

The third kind does not scale with Dynamic Type and is not proportional to anything. The one place a
size is centralised — `NoSpoilersWordmarkSize.fontSize` (`SharedChrome.swift:81-108`) — carries a
seven-line comment justifying 9pt against a 300pt popover row, which is exactly the kind of
reasoning that belongs in a type scale rather than in a component.

### A3. Radii, strokes, and surfaces — repeated literals with no names

| Literal | Meaning | Sites |
| --- | --- | --- |
| `RoundedRectangle(cornerRadius: 2)` | session accent bar | 4 |
| `cornerRadius: 8, style: .continuous` | session row (mac, widget) | 2 |
| `cornerRadius: 10, style: .continuous` | session row (iOS) | 2 |
| `cornerRadius: 6, style: .continuous` | menu row hover | 1 |
| `Color.white.opacity(0.65)` | session row fill | 4 |
| `BrandPalette.mistGrey.opacity(0.55)`, `lineWidth: 1` | card stroke | 1 |
| `BrandPalette.blush.opacity(0.5)` / `0.3` | tinted screen header | 2, different values for the same role |

The same "session row" surface is 8pt-radius white-65% in two targets and 10pt-radius white-65% in
the third. Nobody decided that.

### A4. Motion — three durations, all inline, all in one file

`.easeInOut(duration: 0.12)` (hover), `0.08` (press), `0.15` (copied flash), plus a bare
`DispatchQueue.main.asyncAfter(deadline: .now() + 2)` for how long "Copied!" stays up
(`NoSpoilersMac/ContentView.swift:22-23, 290, 295`). Nothing else in the product animates at all.
There is no motion vocabulary to reskin, and no shared answer to "how fast does this app feel".

### A5. Iconography — 10 SF Symbol literals and one emoji, uncentralised

`flag.checkered.2.crossed` (×2, one as a default parameter value in `NoSpoilersMessageCard`),
`calendar.badge.exclamationmark`, `square.grid.2x2.fill`, `location.fill`, `info.circle` (×2),
`globe`, `gear`, `power`, `arrow.up.circle.fill` — plus the 🏁 fallback in `FlagImage.swift:24`.

Swapping symbol sets means grepping for string literals across four files, and the emoji fallback is
not a symbol at all so it will be missed.

### A6. Opacity — 21 magic multipliers

`0.06, 0.08, 0.10, 0.12, 0.15, 0.3, 0.5, 0.55, 0.6, 0.65, 0.7, 0.72, 0.74, 0.75, 0.78, 0.82, 0.88`.
Several encode the same intent (a "quiet tint" is 0.08, 0.10, 0.12, and 0.15 depending on file).

## B. Components implemented more than once

The reskin cost is not the tokens — it is that changing a component means finding all its copies.

| Component | Implementations | Where |
| --- | --- | --- |
| **Session row** | **4** | `NoSpoilers/ContentView.swift:254-277`, `NoSpoilersMac/ContentView.swift:167-191`, `NoSpoilersWidget.swift:555-582` (`widgetSessionRow`), `NoSpoilersWidget.swift:346-360` (`smallSessionRow`) |
| **Weekend header** | 3 | `NoSpoilers/ContentView.swift:200-236`, `NoSpoilersMac/ContentView.swift:120-153`, `NoSpoilersWidget.swift:518-553` |
| **"Next up" footer** | 3 | `NoSpoilers/ContentView.swift:283-308`, `NoSpoilersMac/ContentView.swift:232-268`, `NoSpoilersWidget.swift:585-619` (+ a fourth inline in `extraLargeView:446-471`) |
| **Empty / message state** | 3 | `NoSpoilersMessageCard` (shared, used by iOS + mac), `NoSpoilersWidget.swift:496-511` (`noDataView`), `NoSpoilersWidget.swift:480-494` (`offSeasonView`) |
| **Screen header** (icon + name + subtitle on blush) | 2 | `AboutView.swift:16-30`, `NoSpoilersMac/ContentView.swift:360-375` |
| **Section label** | 2 | `AboutView.swift:93-102` (`sectionHeader`), `NoSpoilersMac/ContentView.swift:421-430` (`sectionLabel`) — identical but for `.top` 12 vs 10 and `.bottom` 4 vs 2 |
| **Label + trailing control row** | 2 | `AboutView.swift:104-117` (`acknowledgementRow`), `NoSpoilersMac/ContentView.swift:411-419` (`settingRow`) — same HStack, same 16/9 padding |
| **Date-range formatter** | 3 | see E2 |
| **Countdown tiering** | 3 | see E3 |

The two screen headers even load the same asset through two different bundle references:
`Image("nospoilers-icon", bundle: .module)` in Core vs `bundle: noSpoilersCoreBundle` from the mac
target. Both are correct; there being two spellings is the smell.

`NoSpoilersMessageCard` proves the convergence is possible — two of the three empty states already
share it. The widget's two do not, which is why the widget's off-season state has a round pill and a
symbol where the app's has a symbol and a title.

## C. Semantics that already disagree — correctness, not style

This is the part that is a bug today, independent of any reskin.

### C1. "What colour is a finished session?" has three answers

| Target | finished | in progress | upcoming |
| --- | --- | --- | --- |
| iOS (`ContentView.swift:461-470`) | `finishedGrey` | `signalRed` | `upcomingAmber` |
| macOS (`ContentView.swift:171`, inline ternary) | `successGreen.opacity(0.6)` | `signalRed` | `upcomingBlue` |
| Widget (`NoSpoilersWidget.swift:631-640`) | `successGreen.opacity(0.75)` | `signalRed` | `upcomingBlue` |

Three implementations of one mapping, differing in both hue and opacity. The macOS popover
additionally paints the finished session's *name and time* green (`ContentView.swift:176, 179`),
which neither other target does.

### C2. Inside one macOS row, the accent bar and the badge disagree

`sessionRow` draws an upcoming session's accent bar in `upcomingBlue`
(`NoSpoilersMac/ContentView.swift:171`) and then puts a `NoSpoilersStatusBadge(style: .upcoming)`
next to it, which is `upcomingAmber` (`SharedChrome.swift:243`). Blue bar, amber pill, same row,
same state. The shared component and the local ternary were never reconciled.

### C3. `docs/brand.md` and the code disagree about the state palette

`brand.md` reserves Success Green for "finished or safe state only" and Upcoming Blue for
"upcoming/future session state only". The iOS app uses **neither** — it uses `finishedGrey` and
`upcomingAmber`, which `BrandPalette.swift:23-24, 26-28` itself annotates as *"supplementary — not
in brand.md"*. So the written spec describes the macOS and widget behaviour and contradicts the iOS
app, and four palette entries plus both text greys exist outside the spec entirely.

Also: `CLAUDE.md`'s routing line lists `brand.md` alongside three files that live in `docs/guides/`;
the actual file is `docs/brand.md`. `docs/guides/brand.md` does not exist.

## D. Colour that escapes the palette

### D1. System semantic colours used beside `BrandPalette`

`.primary`, `.secondary`, `.tertiary`, and `Color.secondary.opacity(0.10)` appear at **18 sites**,
concentrated in `NoSpoilersMac/ContentView.swift` (13) and `AboutView.swift` (3). These do not move
when the palette moves. They are also the reason both surfaces have to force
`.preferredColorScheme(.light)` (`NoSpoilersMac/ContentView.swift:349`, `AboutView.swift:90`) — the
gradient behind them is hardcoded light, so the system colours have to be pinned to match it.

`brand.md` says "do not define colour constants in individual targets", and that rule is honoured.
It does not say "and do not use system colours instead of the palette", and that is what happens.

### D2. One-off colours not in the palette and not in the spec

- `Color(red: 0.96, green: 0.95, blue: 0.94)` — the iOS finished-weekend background
  (`NoSpoilers/ContentView.swift:140`). Unnamed, undocumented, and the only place the app changes
  its background based on state.
- `Color.orange` — update-available banner background and text, and the menu bar dot
  (`NoSpoilersMac/ContentView.swift:273, 302`, `NoSpoilersMacApp.swift:46`).
- `.green` — the "Copied!" confirmation (`NoSpoilersMac/ContentView.swift:294`), which is *not*
  `successGreen`.
- `Color.white` — the third gradient stop in `NoSpoilersBackground` (`SharedChrome.swift:115`) and
  the session-row fill, where `ivory` is what `brand.md` says to prefer over pure white.

### D3. The accent colour is unset in all three targets

`AccentColor.colorset/Contents.json` in `NoSpoilers/`, `NoSpoilersMac/`, and `NoSpoilersWidget/` all
contain a single `{"idiom": "universal"}` with **no colour defined**. The system tint therefore
falls back to Apple default blue, which is what currently renders the `Link` underline colour and
the default-action "Done" button in `AboutView`, and the sheet furniture on iOS.

There is a brand-relevant colour on screen today that lives in no palette and is set nowhere.

### D4. Dark mode is not a variant, it is disabled

Both hosted surfaces force `.preferredColorScheme(.light)` and the widget's
`containerBackground` is a hardcoded light gradient. Any reskin that is not also warm-light needs a
semantic colour layer (`surface`, `surfaceRaised`, `textPrimary`, `textSecondary`, `separator`)
that does not exist. Whether that is in scope is an open question below — but every hour spent on
tokens without it will need redoing if the answer is yes.

## E. Strings and formatting

### E1. The same string is defined in three files

| String | Defined in |
| --- | --- |
| `roundLabel(_:)` → `"R\(round)"` | iOS, macOS, widget — identical |
| `inProgress` → `"In Progress"` | iOS, macOS, widget — identical |
| `comingUp` → `"Next up"` | iOS, macOS, widget — identical |
| `dateRange(start:end:)` | iOS (`"to"`), macOS (`"→"`), widget (`"→"`) — **not** identical |
| `durationHours` / `durationMinutes` | iOS, macOS — identical |
| `unavailableTitle` → `"Schedule unavailable"` | iOS, widget — identical; bodies differ correctly |
| `done` → `"Done"` | Core (`About`), macOS (`Settings`) |

`swift-patterns.md` already states the rule that decides these: *"Shared strings that cross target
boundaries belong in `NoSpoilersCore/…/Strings.swift`."* They cross, and they have not moved. A
translator localising this app would be handed "In Progress" three times.

### E2. Date-range formatting is written three times

`NoSpoilers/ContentView.swift:454-459`, `NoSpoilersMac/ContentView.swift:141-144` (inline in the
header, not even extracted), `NoSpoilersWidget.swift:621-629`. All three build
`Date.FormatStyle().day().month(.abbreviated)`, format both ends, and collapse when equal. Three
copies of one formatting rule, and they use two different separators. **A formatting pattern is a
design token**; this one is a copy-paste.

### E3. Countdown tiering is written three times

`NoSpoilers/ContentView.swift:437-444` (stops at minutes), `NoSpoilersMac/ContentView.swift:223-230`
(down to seconds), `ScheduleStore.menuBarLabel:76-92` (stops at hours) — plus the widget, which uses
`Text(date, style: .relative)` and gets the system's answer instead.

The *granularity* differences are deliberate and each is documented with a good reason. The
if-days-else-hours-else-minutes **ladder** is not; it is the same logic three times over three
different `Strings` namespaces. One `CountdownFormatter(granularity:)` in Core would keep every
documented divergence as a parameter.

### E4. Dead strings

Unused anywhere in product code, verified by grep: `Strings.App.name` (iOS),
`Strings.Sessions.roundLong` (iOS), `Strings.Sessions.weekendComplete` (iOS — the used one is
`weekendCompleteStatus()`), `Strings.Widget.weekendCard`, `Strings.Widget.locationAndCountry`,
`Strings.Widget.locationAndCountrySmall`. Delete on the way past.

## Recommended shape — needs approval before implementation

This introduces a new abstraction family, which `.claude/rules/core.md` says to propose rather than
spread. The proposal:

**1. A `Theme` namespace in `NoSpoilersCore`, built the way `BrandPalette` already is** — public
static constants on nested enums, no environment plumbing:

```
Theme.Palette   → re-export or absorb BrandPalette, plus semantic roles
                  (surface, surfaceRaised, separator, textPrimary/Secondary/Tertiary,
                   stateFinished/Live/Upcoming)
Theme.Space     → xs … xxl, one scale, replacing all 59 padding + 69 spacing literals
Theme.Radius    → hairline(2) … card(density-driven)
Theme.Type      → named roles (screenTitle, cardTitle, rowLabel, rowDetail, badge, caption)
                  resolved per density, replacing all 88 .font calls
Theme.Motion    → hover, press, confirm, plus the confirmation-hold duration
Theme.Icon      → every SF Symbol name, including FlagImage's fallback
```

Static constants rather than `@Environment`, deliberately: the menu bar label is an `NSHostingView`
built by an `AppDelegate`, and the widget renders in an extension process with no app environment to
inherit — an environment-keyed theme would have to be re-injected at three roots and would silently
fall back to a default at any root someone forgets. If a *runtime* theme switch is ever wanted, that
is a different design and should be decided before this is written, not after (see open questions).

**2. Fold `NoSpoilersCardDensity` into `Theme` as the single density axis** and delete every
`compact: Bool` parameter (`NoSpoilersStatusBadge`, `widgetHeader`, `widgetSessionRow`,
`widgetComingUp`). One concept, one spelling.

**3. Converge the duplicated components into `SharedChrome`**, in descending order of payoff:
`NoSpoilersSessionRow` (4 → 1), `NoSpoilersWeekendHeader` (3 → 1), `NoSpoilersNextUpFooter` (4 → 1),
`NoSpoilersScreenHeader` (2 → 1), `NoSpoilersSectionLabel` (2 → 1), `NoSpoilersDetailRow` (2 → 1),
and make the widget's two empty states use `NoSpoilersMessageCard`.

**4. One `SessionStatus → colour` mapping**, in Core, next to the palette. Deleting two of the three
answers is a visible behaviour change on at least one platform and needs a decision on which
survives — see open questions.

**5. Move the shared strings to Core**, delete the dead ones, and extract
`Strings.Schedule.dateRange` and `CountdownFormatter` beside the existing
`Strings.Schedule.sessionDateTime`, which is already the shared-formatting precedent.

**6. Set the accent colour** in all three asset catalogs to `signalRed`, and extend `docs/brand.md`
past colour to cover the whole token set — or move it to `docs/guides/brand.md` where `CLAUDE.md`
already points.

## Suggested ordering

Each phase is independently shippable and independently verifiable. Phases 1-2 are pure additions
with no behaviour change; the risk starts at phase 3.

1. **Tokens, unused.** Add `Theme` with values transcribed from what is on screen today. Nothing
   consumes it. Zero risk, and it makes the rest reviewable as "call site now names its constant".
2. **Strings + formatters.** Move the shared strings to Core, delete the dead ones, extract the
   date-range and countdown formatters. Behaviour-preserving and covered by the existing tests.
3. **Resolve the state-colour disagreement** (C1/C2/C3) as an explicit product decision, then
   implement it once in Core. This is a visible change and should land alone.
4. **Converge the components**, one per commit, biggest first. Each replaces N implementations with
   one and deletes the others in the same commit — no migration period, per `core.md`.
5. **Sweep the call sites onto the tokens**, target by target.
6. **Accent colour, `brand.md`, and the routing pointer.**

## Verification

`scripts/verify-core-tests.sh`, `scripts/verify-mac-build.sh`, `scripts/verify-ios-build.sh`,
`scripts/verify-widget-build.sh` cover compilation and the domain logic.

**They do not cover any of what this task changes.** There are no UI tests and no snapshot tests in
this repo; a component convergence that renders the wrong thing compiles and passes everything.
`scripts/screenshots.py` renders the widget families into `tmp/screenshots/` from a fixture and is
the closest thing to a visual check that exists — it should be run before and after each phase-4
commit and the pairs compared by eye. **That gap is the largest risk in this task and should be
weighed before starting phase 4**; a snapshot-test harness may be the honest prerequisite, and if so
it is its own task, not a footnote in this one.

## Open questions — answer before phase 1

1. **Is "reskin" a rebuild-time change or a runtime one?** Swapping the palette in source and
   shipping a new build is what the recommendation above assumes. A user-selectable theme is a
   materially different design (environment-injected, three roots to plumb, widget entry needs the
   choice carried through the timeline) and is much cheaper to design in now than to retrofit.
2. **Does dark mode come with the reskin?** If yes, the semantic colour roles in D4 are part of
   phase 1 rather than a later addition, and `.preferredColorScheme(.light)` comes out.
3. **Which state palette wins** — iOS's grey/amber or the macOS+widget green/blue? `brand.md`
   currently says green/blue; two of three implementations agree with it; the app most users see
   does not.
4. **Is `docs/index.html` in scope?** It already has a working token layer with the same colour
   names. Keeping the two in sync by hand is what `brand.md` currently asks for, and a reskin is
   exactly when that breaks.

## Related

- `docs/brand.md` — the colour spec. Colour-only, and drifting from `BrandPalette` (see C3).
- `docs/guides/swift-patterns.md` — "Strings and localisation" already contains the rule that
  decides E1; "Core rules" and "Refactoring bias" decide section B.
- `.claude/rules/core.md` — *"If a shared abstraction almost fits, refactor it instead of creating a
  variant beside it."* `SharedChrome` is that abstraction, and B is a list of variants beside it.
- `NoSpoilersCore/Sources/NoSpoilersCore/SharedChrome.swift` — the existing boundary this task
  extends rather than replaces.

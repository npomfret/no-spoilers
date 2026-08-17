# Task 27: the app cannot be reskinned — colour is the only token that exists

**Status: OPEN, phases 1-4 landed 2026-08-17. `Theme` exists in
`NoSpoilersCore/Sources/NoSpoilersCore/Theme.swift`. `Palette` is consumed by phase 3; `Canvas`,
`Space`, `Radius`, `Icon` and most of `Typography` by phase 4 and the shared components it built.
`Motion` is still unused, and so is every call site outside those components — that is the sweep in
phase 5. Read "Progress" immediately below, then "Decisions" at the end. Everything from section A
onwards is the original review and still describes the code as it stands, except where Progress
says otherwise.**

## Progress

**Phase 1 — tokens, unused. Landed in four commits, `761a3c9`, `0183fbc`, `ba54c08`, `120a7e6`.**

`Theme.Space` (8 steps), `Theme.Radius` (4), `Theme.Motion` (4), `Theme.Icon` (10),
`Theme.Palette` (9 roles), `Theme.Canvas` (5 cases), `Theme.Typography` (2 roles so far).
Verified each time with `scripts/verify-core-tests.sh` — 62 tests, 0 failures.

What the implementation changed about the plan, and why:

1. **The density axis could not be three cases** (contradicts item 2). The widget's medium and
   large families share one card geometry and deliberately do not share a type size —
   `widgetSessionRow` draws `.caption` in medium and `.subheadline` in large, threaded as a
   separate `compact: Bool`. So `Theme.Canvas` has a case per surface: `iosApp`, `macPopover`,
   `widgetSmall`, `widgetMedium`, `widgetLarge`. Approved 2026-08-17.
2. **`NoSpoilersCardDensity.widget` is unreachable today.** The widget target uses neither
   `NoSpoilersCard` nor `NoSpoilersMessageCard`, so those five values are dead code. This is why
   the axis conflict has stayed hidden — it goes live exactly when phase 4 moves the widget's
   empty states onto `NoSpoilersMessageCard`.
3. **`Theme.Type` is `Theme.Typography`.** `Theme.Type` is ambiguous with Swift's metatype syntax.
4. **`Theme.Surface` is `Theme.Canvas`,** so the axis does not collide with `Theme.Palette.surface`.
   The colour keeps the word, since that is the CSS and design-system usage.
5. **The semantic colour roles are not a pure transcription** (refines D4). iOS and the shared
   components already draw `smoke`/`secondaryText`/`tertiaryText`, so for them the sweep is a
   rename. macOS and `AboutView` use the system's `.primary`/`.secondary`/`.tertiary` at **22**
   sites, not 18, and a system label is neutral where `smoke` is warm. Adopting the roles will
   visibly change macOS text colour. That belongs to the sweep, with screenshots.
6. **`NoSpoilersWidget.swift:574` is not a row detail** (corrects the reading behind B). It is a
   secondary *name*, rendered only when compact, so `widgetLarge` has no row detail line at all and
   "row detail" is not a complete ladder across the five canvases.
7. **Deliberately not tokenised yet**, each with its reason in the source: card radii and card fill
   opacities (`NoSpoilersCardDensity` already owns them — restating would make two answers), and
   asset names (`"nospoilers-icon"` ×3, `"flag-\(code)"`, which come entangled with the
   two-bundle-spelling problem that the screen-header convergence resolves).

A `Theme.Typography` role is only added once every one of the five canvases has a real call site to
transcribe. `weekendTitle` and `rowLabel` qualify; the rest do not yet. Roles that genuinely do not
exist on a canvas should fail loudly there rather than return an invented value or an optional.

**Phase 2 — strings and formatters. Landed in five commits, `fa1d124`, `f1d702f`, `dc34f36`,
`1922cd9`, `cf44065`.** Core tests went 62 → 72; all three target builds pass at each commit.

- **2a** deleted E4's six dead strings, each re-checked by grep first.
- **2b** moved `roundLabel`, `inProgress`, `comingUp`, `durationHours`, `durationMinutes` and
  `unavailableTitle` into `Strings.Schedule`, repointing 23 call sites. Only the *title* of the
  unavailable state is shared; each target's body correctly says something different.
- **2c** collapsed "No Spoilers" from four definitions to one and "Done" from two to
  `Strings.Actions.done`. The widget's copy was `configurationDisplayName` — the name the Home
  Screen gallery shows, so a rename that missed it would have been visible in the place users pick
  the widget from.
- **2d** replaced three date-range implementations with `Strings.Schedule.dateRange(from:to:)`.
  **Not a pure move:** iOS said "to" where macOS and the widget said "→", so iOS changed. Four
  tests, one of which caught a bad fixture of my own — 23:30 UTC is already the next day in London
  under BST.
- **2e** replaced two of the three countdown ladders with `CountdownFormatter(units:floor:)`.

**E3 was filed without noticing that `DurationBreakdown` already decided it** (its doc comment:
tier selection is a per-surface product decision, only the arithmetic is shared). That decision
stands. What was extracted is narrower: iOS and the popover turned out to share one rule — show N
units counting from the largest non-zero one, down to a floor — as (2, minutes) and (3, seconds).
**The menu bar does not fit any N.** It shows `in 3d`, `2h 15m`, `15m`: one unit, two, then one,
with the prefix on the days rung only. Folding it in would change the label in the surface that
shares one line with the app icon and a flag, so it keeps its ladder and now says why. Decided
2026-08-17. Equivalence is tested by keeping both original ladders and diffing ~10,800 intervals.

### The `successGreen` contrast figure — measured, and it changes the framing

Computed exactly from the WCAG sRGB formula rather than estimated. `successGreen` `#2E9B63`:

| Against | Ratio | AA body 4.5:1 | AA large / UI 3:1 |
| --- | --- | --- | --- |
| white | 3.51 | fail | pass |
| ivory (`Palette.surface`) | 3.31 | fail | pass |
| `surfaceRaised` (white 65% over ivory) | 3.43 | fail | pass |
| blush | 2.60 | fail | **fail** |

C4's estimate of ~3.5:1 was right for white. **But the comparison numbers reframe it**, because
almost nothing in this palette clears 4.5:1 on ivory: `signalRed` is 3.93, `upcomingBlue` 3.89,
`finishedGrey` **2.75**, and only `smoke` (16.25) really passes.

So per surface, adopting green for finished-session *text*:

- **iOS improves** — the finished label goes from `finishedGrey` 2.75 to 3.31.
- **macOS is unchanged** — the popover already paints finished names green.
- **The widget regresses** — its session names are `smoke` (16.25) today, and would drop to 3.31 if
  the converged session row paints finished names green. **This is the only real regression in the
  change, and it is a phase-4 consequence rather than a phase-3 one.**

If a text-weight companion is wanted, **`#278253`** clears 4.5:1 on ivory at the same hue and
saturation — 16% darker. That is still a new palette entry needing approval. The alternative that
needs no new colour is to keep finished *names* on `smoke` everywhere and let green carry only the
accent bar, badge and tint, all of which clear the 3:1 UI bar. Blush is the one background green
should not be drawn on at all.

**Phase 3 — state colours. Landed in `7a2faeb`, on its own commit as the task asked.**

**Decided 2026-08-17: green carries the bar and the badge only; session names stay on
`textPrimary` in every state.** That follows from the contrast measurement above rather than from
taste — 3.31:1 clears the 3:1 bar for UI components and large text, and misses 4.5:1 for body
text. So no `#278253` entry was needed and **no new palette colour exists**.

`Theme.Palette.state(_:)` is the single mapping. It replaced iOS's `statusColor`, the macOS inline
ternary and the widget's `accentColor`. **C2 is fixed as a side effect and the screenshot proves
it**: the widget's Race row drew a blue accent bar beside an amber badge, because the bar was a
local ternary and the badge was `NoSpoilersStatusBadge`.

Visible changes, all intended: iOS finished rows lose their grey tint entirely (label →
`textPrimary`, detail → `textSecondary`, fill → `surfaceRaised`, which is what the other two
targets already drew); macOS finished names and times stop being green; the widget's finished bar
goes from 75% green to full. `finishedGrey` and `upcomingAmber` are deleted, closing half of C3 by
subtraction.

**On the verification gap.** The screenshot path worked and was worth running, with two things
learned that are not in Verification above:

1. **The capture needs a *signed* simulator build.** Building with `CODE_SIGNING_ALLOWED=NO`, which
   is what `verify-ios-build.sh` does, strips the entitlement that creates the App Group container,
   so `screenshots.py` fails at `get_app_container` with exit 117 and the fixture can never be
   seeded. Build for the simulator destination without that flag.
2. **Diff the pair, do not eyeball it.** A pixel diff bounded the change to the widget card and the
   clock: the wallpaper and dock band came back with a max channel delta of 1. Comparing "by eye"
   would not have established that nothing else moved.

That covers the widget only. **The macOS popover and the iOS pager still have no capture path**,
and most of phase 3's visible change landed in exactly those two. The "is a snapshot harness a
prerequisite" question is therefore still open and still the largest risk in the task — phase 4
converges the components those two surfaces draw.

**Phase 4 — component convergence. Landed in seven commits, one per component as the phase asked:
`072f9b0`, `57c65b2`, `e36a818`, `0d7de71`, `82d4f8a`, `4badfff`, `fcccf33`.** Core tests 72/0 and
all three target builds pass at every one.

| Component | Planned | Actual | Landed as |
| --- | --- | --- | --- |
| Session row | 4 → 1 | 4 → 1 | `NoSpoilersSessionRow` |
| Weekend header | 3 → 1 | **1 line only** | `NoSpoilersWeekendMeta` |
| "Next up" footer | 4 → 1 | 4 → 1 (of 5 sites) | `NoSpoilersNextUpFooter` |
| Screen header | 2 → 1 | 2 → 1 | `NoSpoilersScreenHeader` |
| Section label | 2 → 1 | 2 → 1 | `NoSpoilersSectionLabel` |
| Detail row | 2 → 1 | 2 → 1 | `NoSpoilersDetailRow` |
| Widget empty states | onto `MessageCard` | done | `NoSpoilersCardDensity.widget` is now reachable |

What the implementation changed about the plan, and why:

1. **The weekend header is not 3 → 1** (corrects section B). Reading all three found four
   genuinely different *designs*, not one design at three sizes: iOS puts the wordmark and flag on
   one line and centres the name beneath, macOS puts all three on a single line, the compact widget
   families draw flag-name-pill in one row, and the large family stacks the name over its metadata.
   One component would have been a switch with four bodies. Only the metadata line repeated, and
   that is what converged.
2. **The next-up footer had five sites, not four.** `extraLargeView`'s is a 140pt sidebar column —
   eyebrow, flag on its own line, name over a pill-and-location row over the countdown — and did
   not converge for the same reason as the header.
3. **`NoSpoilersMessageCard.bodyText` had to become optional.** Captured against a hand-seeded
   all-past cache, `systemSmall` fits the icon, the title and two lines of `.caption`; the
   off-season body ran to a third and truncated mid-word. The plan assumed the card would simply
   fit.

Decisions the convergence forced, each recorded in the source and the commit that made it:

- **Session-row radius 8, not 10.** iOS was 10 against 8 in the other two for the same surface.
  8 won on majority; `Radius.large` had no other site and is deleted.
- **The "Next up" eyebrow is tertiary, not `signalRed`.** The widget painted it red, the apps grey.
  Red is this product's live-session signal — `Palette.state` and the small widget's in-progress
  line both use it — and a weekend that has not started is the opposite of live.
- **Section-label padding 12/4, not 10/2.** Not platform intent: `AboutView` is shared, so on macOS
  both screens render in the *same* popover at two different rhythms.
- **Detail-row vertical padding 8, not 9.** Both sites used 9 — two of the eleven off-grid literals
  `Space` records, and as it turns out both of them.
- **The bundle spelling is `noSpoilersCoreBundle` everywhere.** It is `.module` by definition, so
  it is the one spelling correct from both sides of the package boundary. `bundle: .module` no
  longer appears in the product, which is what let `Theme.Icon` finally name the asset strings.

Two hidden fallbacks were removed as side effects, both the same bug: the widget's `sessionDateRange`
returned the *location* when a weekend had no sessions, and iOS's next-up countdown was
`... ?? weekend.location`. Both drew a place name where a date or a time belongs. The converged
components take `String?`/`Text?`, so the line is simply absent.

**On verification.** The medium widget diffs pixel-identical before and after the session-row and
next-up-footer commits, bar the status-bar clock and one countdown glyph — a component that replaced
four implementations renders the fourth byte-for-byte. The large family and both off-season families
were captured and inspected. **The macOS popover and the iOS pager still have no capture path**, and
they took visible colour changes in five of the seven commits (system `.primary`/`.secondary`/
`.tertiary` → warm `Palette` roles, arriving ahead of phase 5's sweep). Those are verified by
compilation only, so the snapshot-harness question is still open and still the largest risk.

**Capture is flaky and the retry is not reliable.** `--install` rewrites SpringBoard's
`IconState.plist`, so the pass that installs is never the usable one; the documented "install once,
then capture again" fixed it about half the time this session, and a widget-less Home Screen exits 0
with a valid PNG. Every capture has to be looked at. The off-season state additionally cannot be
produced by `screenshots.py`'s fixture at all — it needs an all-past cache seeded *after* the
install and *after* the widget is placed.

**Phase 4b — one axis, not three. Landed in two commits, `27bd96b` and `e53986f`.** This is
recommendation 2 ("fold `NoSpoilersCardDensity` into `Theme` and delete every `compact: Bool`"),
which phase 4 left out because it is not one component. It belongs before phase 5: the sweep reads
these parameters at almost every call site it touches, and doing it after would mean editing them
twice.

There were **three** spellings of "which surface am I on", not the two the plan named:

| Axis | Cases | Read by |
| --- | --- | --- |
| `NoSpoilersCardDensity` | regular / compact / widget | `NoSpoilersCard`, `NoSpoilersMessageCard` |
| `compact: Bool` | 2 | `NoSpoilersStatusBadge` + two widget-private helpers |
| `Theme.Canvas` | 5 | everything phases 1-4 added |

Density became `Theme.Card.geometry(_:)` — one switch returning the seven correlated values, since
a card's radius is not independently choosable from its padding — plus `Theme.MessageCard`. The
boolean became `Theme.Badge`.

**Nothing on screen moved except one badge.** regular's numbers are `iosApp`, compact's are
`macPopover`, and widget's are all three widget families, which is exactly what `.widget` already
resolved to. The exception is the drift the boolean was hiding: macOS `stateLabel` passed
`compact: true` for its live and upcoming badges and nothing at all for its finished one, so one
switch drew two badge sizes in the same row. Settled as `.caption2`, two sites against one; the
popover's finished badge is 1pt smaller.

**What the merge actually bought**, beyond one vocabulary: `NoSpoilersMessageCard.bodyText` is
required again. It had to be optional under the three-case axis because `.widget` could not tell
`systemSmall` — which has no room for the explanatory line — from the two families that do, so the
widget's *view code* computed the absence and passed `nil`. `Theme.MessageCard.showsBody` answers
it from the canvas. `NoSpoilersCard` also lost its `.regular` default, which had meant a macOS or
widget caller that forgot the parameter silently got a 24pt radius inside a 300pt popover.

Verified: core tests 72/0 and all three builds at both commits. Four widget captures band-diffed
against the phase-4 shots — off-season at small and medium after the first commit, the active
weekend at medium and large after the second — each one changed band, the status-bar clock. The
macOS popover's badge change is compile-verified only.

**Still to do: phases 5-8 as listed under "Suggested ordering".**

**Scope, as decided: a rebuild-time reskin (no runtime theme switch), no dark mode yet, the
green/blue state palette wins, and `docs/` — the website — is in scope alongside the three app
targets.**

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

This is the part that is a bug today, independent of any reskin. **Decided: green/blue wins** — the
`brand.md` spec and the macOS/widget behaviour are correct, and the iOS app is the outlier that
moves. What that actually costs is spelled out in C4, because it is not the one-file change it
looks like.

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

### C4. What "green/blue wins" actually costs

Not an iOS-only edit. The shared badge is where most of it lands:

- **`NoSpoilersStatusBadge`** (`SharedChrome.swift:231, 243, 246`) uses `finishedGrey` and
  `upcomingAmber` — so the badge is currently amber-for-upcoming on **all three targets**. Moving it
  to blue changes macOS and the widget too, and in doing so **fixes C2 for free**: the macOS row's
  blue accent bar and its badge finally agree.
- **`NoSpoilersRoundPill(isFinished:)`** (`SharedChrome.swift:195, 198`) uses `finishedGrey` for
  both foreground and tint. Same decision applies, same three targets affected.
- **iOS session row** (`ContentView.swift:262, 265, 276`) tints finished rows' label, detail, and
  background with `finishedGrey`. Finished text becomes green, which is what macOS already does
  (`NoSpoilersMac/ContentView.swift:176, 179`).
- **iOS `statusColor`** (`ContentView.swift:461-470`) and the macOS inline ternary
  (`NoSpoilersMac/ContentView.swift:171`) both get deleted in favour of the one mapping.
- **`BrandPalette.finishedGrey` and `.upcomingAmber` become unreferenced** and should go with them.
  They are two of the four entries the file itself annotates as *"not in brand.md"*, so deleting
  them closes half of C3 by subtraction rather than by amending the spec.
- The opacity divergence (`0.6` on macOS, `0.75` in the widget, none on the accent bar) is not a
  decision anyone made and collapses to one value in the shared mapping.

**Contrast risk, and the one thing here that may need a new colour.** `successGreen` is `#2E9B63`;
against white its contrast ratio computes to roughly **3.5:1** (sRGB relative luminance ≈ 0.250).
That clears the 3:1 bar for large text and UI components but is **below the 4.5:1 WCAG AA bar for
body text** — and this change puts finished-session labels at `.body`/`.caption`/11pt onto it in all
three targets. The macOS popover already does this today, so the exposure exists before the change;
green/blue widens it. Confirm the figure with a contrast checker, and if it holds, the honest fix is
a darker `stateFinishedText` beside `successGreen` for type, keeping `successGreen` for the 3pt
accent bar and tints. That is a **new palette entry and needs approval** — it is not implied by
"green/blue wins".

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

### D4. Dark mode is not a variant, it is disabled — and stays that way for now

Both hosted surfaces force `.preferredColorScheme(.light)` (`NoSpoilersMac/ContentView.swift:349`,
`AboutView.swift:90`) and the widget's `containerBackground` is a hardcoded light gradient.

**Decided: no dark mode yet.** The forcing stays, and no dark values get written.

That does **not** retire D1. Replacing `.primary`/`.secondary`/`.tertiary` with named palette roles
is a reskin blocker on its own merits — a system colour does not move when the palette moves, which
is the whole problem, and it is why those two `.preferredColorScheme(.light)` calls exist in the
first place. So phase 1 still defines `textPrimary`, `textSecondary`, `textTertiary`, `separator`,
`surface`, and `surfaceRaised` as **single-value roles**, mapped to what is on screen today
(`smoke`, `secondaryText`, `tertiaryText`, `mistGrey`, `ivory`, white-65%).

The point of naming them now, with one value each, is that adding dark mode later becomes "give each
role a second value" rather than "find every colour decision again". Do not build a variant
mechanism to hold values nobody has chosen — one value per role, and the roles are the seam.

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

## F. The website — in scope, and it has the same disease in CSS

**Decided: `docs/` is in scope.** It is not a bystander; it is where the fourth and fifth copies of
the palette live.

`docs/index.html` (505 lines) and `docs/privacy.html` (148 lines) each carry their **own `:root`
block**, hand-copied:

```
--signal-red --deep-maroon --ivory --smoke --mist-grey --blush
--mid --light --bg --card --border --radius        (both files)
--success-green --mono                              (index.html only)
```

Findings:

- **The token block is duplicated across two files** with no shared stylesheet. `privacy.html` is
  already missing `--success-green`, which is how this kind of drift starts.
- **`--mid` (`#5F5754`) and `--light` (`#827876`) are the web spellings of `secondaryText` and
  `tertiaryText`** — same role, different name, different value. Nine uses across `index.html`.
  Neither pair appears in `docs/brand.md`.
- **Five hardcoded hexes escape `:root`** in `index.html`: `#fdf8f6` (line 99), `#f3dedd` (114),
  `#fff` twice and `#9df3c7` (123-124). The last is a lightened `--success-green` for a hover state,
  invented inline.
- **`--radius: 16px` is the web's card radius**; the app's is 24/18/14 by density. Nobody has
  decided whether those are meant to be the same number.
- The web has `--card`, `--border`, and `--bg` as named surfaces — roles the Swift side does not
  have at all (see A3). **The CSS is ahead of the Swift here** and its naming is worth copying
  rather than inventing a second vocabulary.

With the website in scope, `docs/brand.md` stops being a colour reference and becomes **the
cross-platform token spec**: one table of names, one set of values, two bindings (a `Theme` enum in
Swift, a `:root` block in CSS). Anything that cannot be expressed in both — SF Symbol names, WidgetKit
densities — is explicitly Swift-only in that document rather than silently absent.

Minimum web work: extract the shared `:root` into one `docs/styles.css` included by both pages, fold
the five stray hexes into named properties, rename `--mid`/`--light` to match whatever the Swift
text roles are called, and add the missing `--success-green` to `privacy.html`.

## Recommended shape — needs approval before implementation

This introduces a new abstraction family, which `.claude/rules/core.md` says to propose rather than
spread. The proposal:

**1. A `Theme` namespace in `NoSpoilersCore`, built the way `BrandPalette` already is** — public
static constants on nested enums, no environment plumbing:

```
Theme.Palette   → absorbs BrandPalette, plus single-value semantic roles
                  (surface, surfaceRaised, separator,
                   textPrimary/Secondary/Tertiary,
                   stateFinished/Live/Upcoming — green / red / blue)
Theme.Space     → xs … xxl, one scale, replacing all 59 padding + 69 spacing literals
Theme.Radius    → hairline(2) … card(density-driven)
Theme.Type      → named roles (screenTitle, cardTitle, rowLabel, rowDetail, badge, caption)
                  resolved per density, replacing all 88 .font calls
Theme.Motion    → hover, press, confirm, plus the confirmation-hold duration
Theme.Icon      → every SF Symbol name, including FlagImage's fallback
```

**As built, this block differs in four ways — see Progress items 1-4.** `Theme.Type` is
`Theme.Typography` and resolves per `Theme.Canvas`, a five-case axis rather than a density;
`Theme.Palette` names roles pointing at `BrandPalette` rather than absorbing it, so there is still
one place a hex lives; and the card radii stay in `NoSpoilersCardDensity` until it is folded in.

**Static constants, settled.** The reskin is rebuild-time, so there is no state to carry and nothing
to inject: a theme change is an edit to these constants and a new build. That also sidesteps what
would otherwise have been the hard part — the menu bar label is an `NSHostingView` built by an
`AppDelegate`, and the widget renders in an extension process with no app environment to inherit, so
an environment-keyed theme would need re-injecting at three roots and would fall back silently at any
root someone forgot.

**If a runtime theme switch is ever wanted, this decision is what gets revisited**, and it is a real
rewrite of the plumbing rather than an extension of it. Naming the roles now (see D4) is what keeps
that from also being a rediscovery of every colour decision.

**Every token that has a web equivalent must be expressible as a CSS custom property**, because
`docs/` is in scope (F). Prefer the CSS side's existing surface names — `card`, `border`, `bg` — over
inventing a second vocabulary in Swift. Swift-only tokens (SF Symbols, WidgetKit densities) are
allowed but must be marked as such in `brand.md`.

**2. Fold `NoSpoilersCardDensity` into `Theme` as the single density axis** and delete every
`compact: Bool` parameter (`NoSpoilersStatusBadge`, `widgetHeader`, `widgetSessionRow`,
`widgetComingUp`). One concept, one spelling.

**3. Converge the duplicated components into `SharedChrome`**, in descending order of payoff:
`NoSpoilersSessionRow` (4 → 1), `NoSpoilersWeekendHeader` (3 → 1), `NoSpoilersNextUpFooter` (4 → 1),
`NoSpoilersScreenHeader` (2 → 1), `NoSpoilersSectionLabel` (2 → 1), `NoSpoilersDetailRow` (2 → 1),
and make the widget's two empty states use `NoSpoilersMessageCard`.

**4. One `SessionStatus → colour` mapping**, in Core, next to the palette, resolving to **green /
red / blue**. Delete `iOS statusColor`, the macOS inline ternary, and the widget's `accentColor`, and
retire `finishedGrey` and `upcomingAmber` from `BrandPalette` once nothing references them. Full
blast radius in C4 — it reaches all three targets through `NoSpoilersStatusBadge` and
`NoSpoilersRoundPill`, not just iOS.

**5. Move the shared strings to Core**, delete the dead ones, and extract
`Strings.Schedule.dateRange` and `CountdownFormatter` beside the existing
`Strings.Schedule.sessionDateTime`, which is already the shared-formatting precedent.

**6. Set the accent colour** in all three asset catalogs to `signalRed`.

**7. One `docs/styles.css`** carrying the `:root` block for both HTML pages, with the stray hexes
folded in and the text-role names matching Swift (F).

**8. `docs/brand.md` becomes the cross-platform token spec** — every token, both bindings, and an
explicit note for the Swift-only ones. Move it to `docs/guides/brand.md`, which is where `CLAUDE.md`
already points and where the other guides live. That move touches the control plane, so it goes
through `claude-setup-maintenance` and updates `docs/guides/important-code.md`.

## Suggested ordering

Each phase is independently shippable and independently verifiable. Phases 1-2 are pure additions
with no behaviour change; the risk starts at phase 3.

1. **Tokens, unused.** Add `Theme` with values transcribed from what is on screen today, including
   the single-value semantic roles from D4. Nothing consumes it. Zero risk, and it makes the rest
   reviewable as "call site now names its constant".
2. **Strings + formatters.** Move the shared strings to Core, delete the dead ones, extract the
   date-range and countdown formatters. Behaviour-preserving and covered by the existing tests.
3. **State colours → green/red/blue**, implemented once in Core per C4, with `finishedGrey` and
   `upcomingAmber` deleted. This is the first visible change and should land alone, on its own
   commit, with before/after screenshots. Settle the `successGreen` contrast question (C4) before
   starting, since the answer may add a palette entry this phase depends on.
4. **Converge the components**, one per commit, biggest first. Each replaces N implementations with
   one and deletes the others in the same commit — no migration period, per `core.md`.
5. **Sweep the call sites onto the tokens**, target by target.
6. **Accent colour** in the three asset catalogs.
7. **Website**: shared `docs/styles.css`, stray hexes named, text roles renamed to match Swift.
8. **`brand.md` rewritten as the token spec and moved to `docs/guides/`**, with
   `docs/guides/important-code.md` updated. Last, so it documents what was built rather than what
   was planned.

Phases 1-2 are pure additions with no behaviour change. Phase 7 is independent of 3-6 and can run in
parallel with them if convenient — it shares no files with the app targets.

## Verification

`scripts/verify-core-tests.sh`, `scripts/verify-mac-build.sh`, `scripts/verify-ios-build.sh`,
`scripts/verify-widget-build.sh` cover compilation and the domain logic.

**They do not cover any of what this task changes.** There are no UI tests and no snapshot tests in
this repo; a component convergence that renders the wrong thing compiles and passes everything.
`scripts/screenshots.py` renders the widget families into `tmp/screenshots/` from a fixture and is
the closest thing to a visual check that exists — it should be run before and after each phase-3 and
phase-4 commit and the pairs compared by eye. **That gap is the largest risk in this task and should
be weighed before starting phase 3**; a snapshot-test harness may be the honest prerequisite, and if
so it is its own task, not a footnote in this one. Note that it covers the widget only: the iOS
pager and the macOS popover — where most of C4's visible change lands — have no capture path at all.

Two checks are not builds and are easy to skip:

- **Contrast.** Verify `successGreen` against `surface` and `surfaceRaised` with a real contrast
  tool before phase 3, per C4. A wrong answer here ships an accessibility regression that compiles.
- **The website.** No build step and no test. Phase 7 is verified by opening `docs/index.html` and
  `docs/privacy.html` and confirming nothing moved — and by grepping that no hex literal survives
  outside the shared `:root`.

## Decisions — 2026-08-17

The four questions that blocked phase 1, and what each one closes.

1. **Rebuild-time reskin, not runtime.** No user-selectable theme. `Theme` is public static
   constants; a reskin is an edit plus a build. Removes the environment plumbing at three roots and
   the widget-timeline question entirely. Revisiting this later is a rewrite of the plumbing, not an
   extension of it — which is why the roles get named now.
2. **No dark mode yet.** `.preferredColorScheme(.light)` stays and no dark values get written. The
   semantic colour roles are still part of phase 1 as **single-value** roles, because D1 is a reskin
   blocker independently of dark mode. One value per role; the roles are the seam a dark variant
   would later hang from. Do not build variant machinery for values nobody has chosen.
3. **Green/blue wins.** (Refined 2026-08-17: green carries the bar and badge only — see Progress.) `brand.md` and the macOS/widget behaviour are right; the iOS app moves.
   Retires `finishedGrey` and `upcomingAmber`. Reaches all three targets through
   `NoSpoilersStatusBadge` and `NoSpoilersRoundPill`, and incidentally fixes C2. **One thing this
   decision does not settle:** whether `successGreen` is legible enough for body text at 3.5:1 — if
   not, a darker `stateFinishedText` is a new palette entry needing separate approval (C4).
4. **The website is in scope.** `docs/index.html` and `docs/privacy.html` each carry a hand-copied
   `:root` block, so they are the fourth and fifth copies of the palette (F). `brand.md` becomes the
   cross-platform token spec with two bindings, Swift and CSS.

## Still open

- ~~**The `successGreen` contrast figure** (C4)~~ — **measured 2026-08-17, see Progress.** 3.31:1 on
  ivory, and the finding is that iOS *improves* while only the widget would regress. What is still
  open is the decision it feeds: a new `#278253` palette entry for text, or keep finished names on
  `smoke` and let green carry only the bar, badge and tint.
- **Whether a snapshot-test harness is a prerequisite** to phases 3-4, given that nothing in the
  repo can catch a visual regression and two of the three surfaces have no capture path. See
  Verification.
- **Whether the web `--radius: 16px` and the app's 24/18/14 densities are meant to relate.** Nobody
  has decided; the token spec will have to say something.

## Related

- `docs/brand.md` — the colour spec. Colour-only, and drifting from `BrandPalette` (see C3).
  Becomes the cross-platform token spec and moves to `docs/guides/brand.md` in phase 8.
- `docs/index.html`, `docs/privacy.html` — in scope; two hand-copied `:root` blocks and five stray
  hexes (F).
- `docs/guides/swift-patterns.md` — "Strings and localisation" already contains the rule that
  decides E1; "Core rules" and "Refactoring bias" decide section B.
- `.claude/rules/core.md` — *"If a shared abstraction almost fits, refactor it instead of creating a
  variant beside it."* `SharedChrome` is that abstraction, and B is a list of variants beside it.
- `NoSpoilersCore/Sources/NoSpoilersCore/SharedChrome.swift` — the existing boundary this task
  extends rather than replaces.

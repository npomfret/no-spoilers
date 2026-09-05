# The token spec

Every design decision this product makes, in one place, with two bindings.

**A reskin is an edit to the values below and a rebuild.** That is the test this document is
measured against: change the accent colour, the type scale, the corner radii, the spacing rhythm,
the motion, or the icon set — one edit each — and the iOS app, the macOS popover, the menu bar
label, all four widget families and the website follow.

The two bindings:

| | Where | Shape |
| --- | --- | --- |
| Swift | `NoSpoilersCore/Sources/NoSpoilersCore/Theme.swift` | public static constants on nested enums |
| CSS | `docs/styles.css` | custom properties on `:root` |

Colour hexes live in **`BrandPalette.swift`**, which `Theme.Palette` points at. That is deliberate:
`BrandPalette` answers "what is signal red", `Theme.Palette` answers "what colour is a finished
session", and there is exactly one place a hex appears on the Swift side.

**Rebuild-time, not runtime.** No user-selectable theme, no environment plumbing. This is what lets
the menu bar label — an `NSHostingView` built by an `AppDelegate` — and the widget — a separate
process with no app environment to inherit — get the same answer as the app without anything being
injected at three roots. Revisiting that is a rewrite of the plumbing, not an extension of it.

**Dark mode follows the system, on both platforms, with no in-app toggle.** Since 2026-09-05 every
surface and text role in §2 has a light value and a dark one, and the host picks: the pairing is a
platform dynamic colour (`Theme.Palette.adaptive`), which resolves against whatever appearance is
current when it is drawn. That is what keeps this inside the rule above — the menu bar label, the
widget, the Live Activity and the app all read the same static constant and each follows its own
host, and nothing reads `\.colorScheme`. The three state colours, `attention`, `confirmation` and
`hoverFill` do not change: the first three were measured on charcoal and clear the same bar they
clear on ivory, the other three are already system colours. Nothing forces `.preferredColorScheme`
any more, and `tasks/28-dark-mode-follows-the-system.md` is why it took a Guideline 4 rejection to
get here.

---

## 1. Palette

The raw colours. Derived from the app icon in `docs/icon.png`.

| Name | Hex | Swift | CSS | Purpose |
| --- | --- | --- | --- | --- |
| Signal Red | `#EF2B2D` | `BrandPalette.signalRed` | `--signal-red` | The brand accent, and the live-session signal |
| Deep Maroon | `#7A0C0F` | `BrandPalette.deepMaroon` | `--deep-maroon` | Dark anchor, shadows, outlines |
| Ivory | `#FFF7F2` | `BrandPalette.ivory` | `--ivory` | The warm light ground, preferred over pure white |
| Blush | `#F6D7D4` | `BrandPalette.blush` | `--blush` | Tinted headers, gradients, soft emphasis |
| Smoke | `#1F1A1A` | `BrandPalette.smoke` | `--smoke` | Dense dark text |
| Mist Grey | `#D9D2CF` | `BrandPalette.mistGrey` | `--mist-grey` | Borders and dividers that should recede |
| Success Green | `#2E9B63` | `BrandPalette.successGreen` | `--success-green` | Finished state only, never general branding |
| Upcoming Blue | `#3D7FCC` | `BrandPalette.upcomingBlue` | — | Upcoming state only |
| Secondary text | `#5F5754` | `BrandPalette.secondaryText` | `--text-secondary` | Supporting copy on ivory |
| Tertiary text | `#827876` ³ | `BrandPalette.tertiaryText` | `--text-tertiary` | Quiet copy on ivory |
| White | `#FFFFFF` | `BrandPalette.white` | — | The lift: rows, cards, the bright end of the gradient. Not a ground |

The dark set, Swift-only — the website has no dark mode. Warm like the light set, so the two
appearances read as one product; each is the dark answer to the light name beside it.

| Name | Hex | Swift | Dark answer to | Purpose |
| --- | --- | --- | --- | --- |
| Charcoal | `#171313` | `BrandPalette.charcoal` | Ivory | The dark ground |
| Oxblood | `#2F1516` | `BrandPalette.oxblood` | Blush | Tinted headers, gradients, pills |
| Graphite | `#2C2626` | `BrandPalette.graphite` | White | The lift above charcoal |
| Cinder | `#3B3333` | `BrandPalette.cinder` | Mist Grey | Borders and dividers |
| Secondary text, dark | `#B9AEAA` | `BrandPalette.secondaryTextDark` | Secondary text | Supporting copy on charcoal |
| Tertiary text, dark | `#8E8480` | `BrandPalette.tertiaryTextDark` | Tertiary text | Quiet copy on charcoal |

Primary text on charcoal is ivory, which already had a name.

³ **Tertiary text is 4.05:1 on ivory, which is short of the 4.5:1 that normal-size text wants.**
Holding the hue, `#79706E` is the value that clears it at 4.55:1. That is recorded rather than
adopted: it is a third value neither binding has ever drawn, and this role is deliberately quiet.

The two bindings disagreed on both of these until 2026-08-18 — Swift held `#6D6663`/`#918782`
against the web's `#5F5754`/`#827876`, because the web's had been renamed from `--mid` and
`--light` without anyone reconciling what they were. Contrast on ivory settled it rather than
seniority: the web pair is darker on both roles, so Swift adopted it. Supporting copy went 5.32:1
→ 6.66:1 and quiet copy 3.31:1 → 4.05:1, and one role now has one value again.

Use Signal Red sparingly — it should feel deliberate, not flood a layout. Prefer Ivory over pure
white for grounds. Success Green marks a completed session and never replaces the brand accent.

**Contrast, measured with the WCAG sRGB formula, not estimated**, and pinned to two decimal places
by `ThemePaletteContrastTests` so that this table and the code cannot drift apart.

| On the ground | Light (ivory) | Dark (charcoal) |
| --- | --- | --- |
| `textPrimary` | 16.25 | 17.42 |
| `textSecondary` | 6.66 | 8.51 |
| `textTertiary` | 4.05 ³ | 5.06 |
| `stateFinished` (success green) | **3.31** | 5.25 |
| `stateLive` (signal red) | 3.93 | 4.44 |
| `stateUpcoming` (upcoming blue) | 3.89 | 4.48 |
| `stateFinished` on a lifted row | 3.43 | 4.62 |

Almost nothing in the light palette clears 4.5:1 on ivory, and only `smoke` really passes. That is
why the state colours carry the accent bar and the badge — UI components, which need 3:1 — while
session **names** stay on `textPrimary` in every state. The dark ground is kinder to all three, which
is why the state colours did not need a dark value. **Do not draw `successGreen` on blush**: 2.60
there fails even the 3:1 bar.

## 2. Semantic colour roles

What a colour is *for*. Two values each where the appearance changes it, and the host picks; the
roles are the seam dark mode hangs from, and the only place a light and a dark colour are paired.

| Role | Swift | CSS | Light | Dark |
| --- | --- | --- | --- | --- |
| Primary text | `Theme.Palette.textPrimary` | `--text-primary` | smoke | ivory |
| Supporting text | `Theme.Palette.textSecondary` | `--text-secondary` | secondary text | secondary text, dark |
| Quiet text | `Theme.Palette.textTertiary` | `--text-tertiary` | tertiary text ³ | tertiary text, dark |
| Dividers | `Theme.Palette.separator` | `--border` ¹ | mist grey | cinder |
| The ground | `Theme.Palette.surface` | `--bg` ¹ | ivory | charcoal |
| The lift, at a caller's opacity | `Theme.Palette.surfaceLift` | — | white | graphite |
| A lifted row or panel | `Theme.Palette.surfaceRaised` | `--card` ¹ | lift at 65% | lift at 65% |
| A soft wash, at a caller's opacity | `Theme.Palette.surfaceTinted` | — | blush | oxblood |
| A weekend that is over | `Theme.Palette.surfaceFinished` | — | `#F4F2EF` ² | `#1D1B1B` ² |
| Finished session | `Theme.Palette.stateFinished` | `--success-green` | success green | same |
| Live session | `Theme.Palette.stateLive` | — | signal red | same |
| Upcoming session | `Theme.Palette.stateUpcoming` | — | upcoming blue | same |
| The app talking about itself | `Theme.Palette.attention` | — | system orange ² | system |
| A control confirming it acted | `Theme.Palette.confirmation` | — | system green ² | system |
| Pointer over a menu row | `Theme.Palette.hoverFill` | — | system secondary at 10% ² | system |

`surfaceLift` and `surfaceTinted` are bases, not finished surfaces: the card multiplies the lift by
0.82/0.78/0.74 per canvas, the row by 0.65, and the three tinted callers use 0.3, 0.5 and 0.7. Those
are the opacities that were on screen when each site read `Color.white` or `BrandPalette.blush`;
naming the base is what let one edit give all of them a dark value. `NoSpoilersBackground` is
`surface` → `surfaceTinted` at 72% → `surfaceLift`, in both appearances.

¹ The web's surface names came first and are better; Swift has not adopted them. Values differ —
`--card` is white at 88% where `surfaceRaised` is 65%, because a web card sits on a photograph.

² Not in the palette and not brand colours, on purpose. `attention` means neither a session state
nor the brand. `confirmation` is the *system* green and deliberately not `successGreen`, which
means "this session is over". Naming them is what makes them findable.

**`Theme.Palette.state(_:)` is the only place a `SessionStatus` becomes a colour.** It replaced
three implementations that disagreed on hue *and* opacity, including a macOS row that drew a blue
accent bar beside an amber badge for the same session.

## 3. Canvas — the axis everything else varies along

**Swift-only.** The web has one canvas.

`Theme.Canvas` has a case per surface: `iosApp`, `macPopover`, `widgetSmall`, `widgetMedium`,
`widgetLarge` (which `systemExtraLarge` shares). Every size-dependent token is a function of it.

A case per surface rather than a density scale, because the widget's medium and large families
share one card geometry and deliberately do *not* share a type size. Anything narrower needs a
second axis beside it, which is what `NoSpoilersCardDensity` and a `compact: Bool` used to be.

**A role is only added once every canvas that draws it has a real call site to transcribe.** Roles
that genuinely do not exist on a canvas `preconditionFailure` there rather than returning an
invented value or an optional — no widget family has a next-up footer, the large one has no second
line in its session row.

## 4. Space

`Theme.Space` — `xxs` 2, `xs` 4, `sm` 6, `md` 8, `lg` 10, `xl` 12, `xxl` 16, `xxxl` 20.

Eight steps on a 2pt grid, transcribed from what was on screen rather than designed. **`spacing: 0`
is not a step** — it means "no gap", an override of SwiftUI's default, and does not move when the
rhythm moves. Glyph sizes are not on this grid either: flag heights, symbol sizes and the numbered
step circles are image dimensions, not gaps.

The eleven off-grid literals found in the original audit are gone, every one rounded **down**:
9→8, 7→6, 3→2, 14→12, 1→2.

The web keeps its own spacing today. Aligning the two is not done and is the obvious next step for
this document.

## 5. Radius

`Theme.Radius` — `hairline` 2 (the session accent bar), `small` 6 (the macOS menu row hover),
`medium` 8 (the session row on every canvas).

CSS — `--radius-hairline` 2px, `--radius-sm` 6px, `--radius-md` 8px, then `--radius-lg` 10px,
`--radius-xl` 12px, `--radius-xxl` 16px.

**The small end is shared and holds the same numbers. The card end is per-surface and does not.**
That is the answer to a question this document used to leave open, and putting the two ladders
side by side is what answered it:

- **`hairline` is literally the same element.** A 3pt-wide vertical session accent bar, rounded on
  one end. Swift rounds it at 2, the web rounded it at 3, and nobody had ever compared them. The
  web moved to 2 on 2026-08-18 — the only pixel this alignment changed.
- **`small` 6 and `medium` 8 already agreed**, independently, before anyone looked.
- **Card radii are per-surface on both bindings**, so there is nothing to reconcile. `Theme.Card`
  resolves 24 / 18 / 14 per canvas alongside the padding, fill and shadow that go with each — a
  card's radius is not independently choosable from its padding. The web is one canvas with three
  block sizes and picks 16 / 12 / 10. Two ladders of three, neither derived from the other.

Before this, the web had one `--radius` and seven raw literals beside it. Every one is now a token
and every token has a call site.

## 6. Typography

**Swift-only, apart from the face.** Every role is a function of `Theme.Canvas`.

`weekendTitle`, `rowLabel`, `rowDetail`, `weekendLocation`, `weekendDateRange`, `eyebrow`,
`nextUpName`, `nextUpDetail`.

`eyebrow` is the one role with no canvas axis, because all four implementations already agreed.

Prefer semantic fonts (`.caption`, `.subheadline`) over `.system(size:)`, which does not scale with
Dynamic Type. Three absolute sizes remain and each says why in the source: the macOS popover's
session row and detail, transcribed to keep it rendering exactly as it does, and the wordmark,
which is sized against a 300pt row.

### The wordmark's face — both sides

**`BrandTypeface.wordmark(size:)` in Swift, `--wordmark` in `docs/styles.css`.** Chivo ExtraBold,
SIL OFL 1.1, bundled — `Chivo.ttf` and `Chivo-OFL.txt` ship in
`NoSpoilersCore/…/Resources/` and again in `docs/`, self-hosted rather than from a CDN.
`tasks/24-wordmark-typeface.md` records why this face and not another; the short version is that
this is the surface rejected three times under 4.1(a), so the face had to be distinctive without
being sport-referential.

**One face, one component, on both sides.** Swift applies it in `NoSpoilersWordmark` and nowhere
else; CSS applies it to `.hero h1` and nowhere else — `privacy.html`'s heading stays in the system
font on purpose. Spreading a display face into the reading surfaces is a separate decision and
neither binding has made it.

**Two things about it that are not obvious and will bite.** It is a variable font whose `wght` axis
defaults to 500, so the PostScript name carries the weight (`Chivo-Medium_ExtraBold`) and asking
for plain `"Chivo"` silently gets Medium. And a missing or misnamed face does not fail a build — it
renders as the system font while every command still reports success. `BrandTypeface` therefore
`precondition`s on the face resolving, and `BrandTypefaceTests` pins both the registration and the
9pt measurement the 300pt popover row was sized against.

## 7. Motion

`Theme.Motion` — `hover` 0.12s, `press` 0.08s, `confirm` 0.15s, `confirmationHold` 2s.

Press is faster than hover, because a press should feel like it has already happened.
`confirmationHold` is how long a confirmation stays up, as distinct from how long the change takes
to draw — the two sat 270 lines apart with nothing saying they were related.

**Every call site is macOS.** Nothing on iOS or in the widget animates: the iOS pager runs its own
interactive transition rather than an `.animation(_:value:)`. This is a vocabulary of four with one
speaker, named so that the next thing wanting to animate picks from a list.

## 8. Icons

**Swift-only.** SF Symbols have no CSS equivalent.

`Theme.Icon` holds every symbol name, the two asset names (`appIcon`, `flag(for:)`), and
`flagFallback` — the 🏁 emoji drawn when a country has no flag asset. That last one is the entry a
symbol-set sweep would otherwise miss, because it is not a symbol name at all.

Assets are always loaded from `noSpoilersCoreBundle`, never `bundle: .module`. Both are the same
bundle; `noSpoilersCoreBundle` is the one spelling that is correct from either side of the package
boundary.

## 9. The one value this system cannot hold

**The system accent colour.** It has to be an `AccentColor.colorset` in each target's asset
catalog, and an asset catalog cannot reference Swift — so signal red's three components are
transcribed into `NoSpoilers/`, `NoSpoilersMac/` and `NoSpoilersWidget/` as JSON as well.

Change `BrandPalette.signalRed` and change those three files. Nothing will fail to compile if you
forget; the app will simply tint itself with the old red.

## Rules

- **Do not define colour constants in a target.** `BrandPalette` is the single source of truth for
  Swift; add there first, then reference.
- **Do not type a number at a call site** when a token names it. If no token fits, either the token
  family needs a new member — with a call site on every canvas — or the number is a glyph size and
  belongs at the call site with a comment saying so.
- **Do not use system colours** (`.primary`, `.secondary`, `.tertiary`) for product text. They do
  not move when the palette moves, which is the whole problem, and now that nothing is pinned light
  they would also move when the palette does not. System controls — toggles, buttons, menus — keep
  theirs; that is what following the appearance means.
- **Do not force a colour scheme.** `.preferredColorScheme(.light)` was how four surfaces survived
  the April 2026 rejection before the roles had dark values. A pin now hides a role that is missing
  one; give it the value instead.
- **A new role that changes with the appearance goes through `adaptive(light:dark:)`**, with both
  hexes in `BrandPalette` under their own names. Do not read `\.colorScheme` to pick a colour.
- **Every user-visible string goes through a `Strings.swift`.** Placeholder text inside a
  `.redacted` view is not user-visible copy — use `Text(verbatim:)`.
- **Both bindings or neither.** A token with a web equivalent must be expressible as a CSS custom
  property. Swift-only families are marked as such above.

## Related

- `NoSpoilersCore/Sources/NoSpoilersCore/Theme.swift` — the Swift binding. Its doc comments carry
  the per-token reasoning; this document is the map.
- `NoSpoilersCore/Sources/NoSpoilersCore/BrandPalette.swift` — where the hexes live.
- `docs/styles.css` — the CSS binding, shared by `docs/index.html` and `docs/privacy.html`.
- `NoSpoilersCore/Sources/NoSpoilersCore/SharedChrome.swift` — the components these tokens dress.
- `tasks/27-design-tokens-and-component-convergence.md` — how this came to exist, and every
  decision made along the way with its evidence.

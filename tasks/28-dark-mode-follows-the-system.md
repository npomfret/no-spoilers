# Task 28: dark mode on iOS and macOS, following the system

**Status: IN PROGRESS. Raised 2026-09-05; phases 1 to 3 landed the same day. Phase 4, the pixels, is what is left.**

## The issue

Both apps are light-only, and on purpose: `docs/guides/brand.md` says "No dark mode" and
`Theme.Palette` has one value per role. The product should instead follow the system appearance
on both platforms. That is the whole product decision: **no in-app toggle**, the brand guide's
"no user-selectable theme" stands, and the widget and Live Activity follow the Home Screen the way
every other widget does.

What holds the light look in place today:

- Four `.preferredColorScheme(.light)` pins: the macOS popover root in
  `NoSpoilers/NoSpoilersMac/ContentView.swift`, the shared `AboutView`, and the iOS `HelpSheet`
  and `SessionAlertsView`. The iOS main screen is not pinned; it draws `BrandPalette` colours on a
  light gradient and so renders light regardless of the device setting.
- Every `BrandPalette` entry is a fixed `Color(red:green:blue:)`; `NoSpoilersBackground` is a
  hardcoded ivory/blush/white gradient; `NoSpoilersCard` fills with `Color.white` at a per-canvas
  opacity; `Theme.Palette.surfaceRaised` is white at 65%; the Live Activity tints its background
  ivory. None of these can move with the appearance as written.

**Why the pins exist, and why they are the wrong fix to keep.** App Review rejected the macOS app
under Guideline 4 in April 2026 (`398258c`): the reviewer ran dark mode, the popover used system
`.primary`/`.secondary`/`.tertiary` text on the light gradient, and every line went white on pale.
Pinning the subtree light was the fix. The task 27 sweep in August 2026 then moved that text onto
`Theme.Palette` roles, so today the pins mostly protect system controls (toggles, buttons, menus)
sitting on a ground that cannot change. Removing the pins without giving the ground a dark value
would reproduce the rejection exactly. The order of work below is chosen to make that impossible.

## Brainstorming

The one real design question is how a colour gets a second value when the brand guide forbids
runtime theme plumbing, because the menu bar label is an `NSHostingView` built by an
`AppDelegate` and the widget is a separate process with no app environment to inherit.

- **Dynamic platform colours inside `BrandPalette` (recommended).** Each entry that changes
  becomes `Color(nsColor:)`/`Color(uiColor:)` over a dynamic provider that returns the light or
  dark value for the current trait. Hexes stay in the one Swift file, `Theme.Palette` roles keep
  their names and call sites, nothing is injected anywhere, and because the colour resolves at
  draw time the widget, Live Activity and `NSHostingView` follow their host for free. Cost: one
  small `#if canImport(UIKit)` helper in `BrandPalette.swift` and a light/dark pair per entry.
- **Asset-catalogue colorsets with Any/Dark appearances in Core's `Resources`.** Same runtime
  behaviour and `Flags.xcassets` is precedent for a `Bundle.module` catalogue, but the hexes leave
  Swift for a dozen `Contents.json` files and the brand guide's "one place a hex lives" stops
  being true. Cheaper to write, worse to read. Not chosen.
- **`@Environment(\.colorScheme)` with `Theme.Palette.resolved(for:)`.** Rejected: this is the
  plumbing the brand guide rules out, it needs injection at three roots, and every static role
  becomes a function at every call site.
- **Stay light-only.** Apple accepted the pinned popover, so this is preference rather than
  compliance. Rejected because the product wants dark mode.

Whether the dark ground is a gradient (smoke into a deep-maroon wash, say) or a flat surface is a
decision to make with pixels in front of it, not here.

## The plan

1. **Choose the dark values.** A dark value for every surface and text role, and a re-measurement
   of the state colours, `attention` and `confirmation` on the dark ground, with the WCAG sRGB
   formula the brand guide already uses. Done when `docs/guides/brand.md` has a dark column with
   measured ratios and the same 3:1 (components) and 4.5:1 (body text) reasoning as the light one.
2. **Make the palette dynamic.** `BrandPalette` entries carry both values; the card fill and the
   gradient's white stop move off literals onto roles; `surfaceFinished` and `NoSpoilersBackground`
   gain dark values. No pin is removed in this phase, so nothing on screen changes yet. Done when
   the four verify scripts pass and `grep -rn 'Color.white\|Color(red' NoSpoilers NoSpoilersCore`
   finds nothing outside `BrandPalette.swift`.
3. **Let the appearance through.** Remove the four pins, drop the ivory Live Activity tint in
   favour of the dynamic surface, and confirm the widget backdrop and the menu bar label need no
   change (if either does, that is a finding to record). Done when `grep -rn preferredColorScheme`
   over the Swift sources finds nothing.
4. **Look at the pixels in both appearances.** Every surface: the iOS main screen in both weekend
   states, the About, Help and Alerts sheets, the macOS popover including Settings with its system
   toggles, all four Home Screen widget families, the Lock Screen families, and the Live Activity.
   iOS via `scripts/screenshots.py` after `xcrun simctl ui <udid> appearance dark`; macOS via
   `scripts/mac_screenshots.py` with the system appearance flipped, which the script does not do
   today and will need to. The specific check is the rejected failure: every piece of text
   readable on its ground in both appearances.
5. **Say so in the docs.** Replace the "No dark mode" paragraph and the single-value claims in
   `docs/guides/brand.md`, the `Theme.Palette` doc comment, and the four call-site comments that
   explain the pins. `docs/guides/building.md` if the screenshot scripts changed.

## Tracking

Decisions taken at filing:

- Follow the system appearance on both platforms; no in-app toggle.
- App Store screenshots stay light; re-shooting the listing in dark is a separate decision.
- The website (`docs/styles.css` has no `prefers-color-scheme`) is out of scope.

Findings from phase 3 (2026-09-05): the widget backdrop and the menu bar label needed no
change, as hoped — the backdrop is `NoSpoilersBackground`, which is three roles now, and the
label draws system text on `Color.clear` with an orange dot, all of which already followed the
menu bar. The Live Activity tint moved from `BrandPalette.ivory` to `Theme.Palette.surface` in
phase 2, since that edit had to happen anyway once ivory stopped being a role.

Decisions taken in phases 1 and 2 (2026-09-05):

- **The pairing lives in `Theme.Palette`, not `BrandPalette`.** The brainstorm said "inside
  `BrandPalette`", and the mechanism is as recommended — a platform dynamic colour, no
  environment read — but the pair is made where the roles are. `BrandPalette` stays one hex per
  name and gains the dark hexes under their own names (charcoal, oxblood, graphite, cinder, and
  the two dark text neutrals), because `ivory` resolving to near-black in dark would make the
  name a lie, and the brand guide already said the roles were the seam.
- **Two new roles, because three call sites needed them.** `surfaceLift` (white / graphite) is
  what the card fill, the row fill and the gradient's bright end multiply; `surfaceTinted` (blush
  / oxblood) is what the mac header, the screen header and the round pill wash with. Each site
  keeps the opacity it had, so light is pixel-identical.
- **Oxblood rather than blush dimmed**, because blush at 30% over charcoal is grey mud. It is a
  maroon-tinted charcoal, the same relationship blush has to ivory.
- **The state colours keep one value.** Measured on charcoal: green 5.25, red 4.44, blue 4.48,
  all clear of the 3:1 component bar with more room than they have on ivory.
- **`surfaceFinished` keeps its literal in `Theme.swift`**, now as a pair (`#F4F2EF` / `#1D1B1B`).
  The phase 2 grep criterion below is read with that one deliberate exception, which the role's
  doc comment has always explained.
- **`ThemePaletteContrastTests` pins every ratio in the guide's table** to two decimal places, in
  both appearances, via `Color.resolve(in:)` with the scheme set. That both stops the table
  drifting from the code and proves the dynamic colour actually answers dark when asked.

Verification:

- [x] `scripts/verify-core-tests.sh` (111 tests), `scripts/verify-mac-build.sh`,
      `scripts/verify-ios-build.sh`, `scripts/verify-widget-build.sh` — all green after phase 2
- [x] `docs/guides/brand.md` dark column with measured contrast ratios
- [x] No `preferredColorScheme` and no colour literal outside `BrandPalette.swift` in the tree
      (the only literals left are the `surfaceFinished` pair; the four pins came off in phase 3
      and all four verify scripts passed again afterwards)
- [ ] Dark and light captures of every surface listed in phase 4, looked at, not just taken

Residual risk: this is the surface that has already been rejected once. Ship it as its own
release, and the first macOS release goes through task 26 anyway.

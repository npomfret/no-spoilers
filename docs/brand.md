# No Spoilers Brand Palette

This palette is derived from the checked-in app icon in `docs/icon.png`.

The goal is simple:

- keep the product visually tied to the icon
- avoid generic pure-white-and-red UI
- reserve the strongest red for real emphasis
- keep finished or safe states out of the brand red system

## Core colors

| Name | Hex | Purpose |
| --- | --- | --- |
| Signal Red | `#EF2B2D` | Primary accent, calls to action, highlighted brand moments |
| Deep Maroon | `#7A0C0F` | Dark accent, depth, outlines, high-contrast emphasis |
| Ivory | `#FFF7F2` | Main background and warm light surfaces |
| Smoke | `#1F1A1A` | Primary text and dense dark UI |
| Mist Grey | `#D9D2CF` | Borders, dividers, subtle structure |
| Blush | `#F6D7D4` | Secondary tint backgrounds and soft emphasis |
| Success Green | `#2E9B63` | Finished or safe state only, not general branding |

## Usage rules

- Use `Signal Red` sparingly. It should feel deliberate, not flood the whole layout.
- Use `Deep Maroon` when the UI needs a darker anchor behind or beside the red.
- Prefer `Ivory` over pure white for page backgrounds.
- Keep most body copy on `Smoke`, with quieter supporting copy in a softened neutral.
- Use `Mist Grey` for structure that should recede.
- Use `Blush` for gradients, tinted cards, and gentle atmospheric fills.
- Use `Success Green` only for completed or safe-to-watch state. Do not replace the brand accent with it.

## Implementation

### Swift (iOS app, macOS app, widget)

All Swift targets consume colours via the shared `BrandPalette` enum in `NoSpoilersCore`:

```swift
import NoSpoilersCore

Text("...").foregroundStyle(BrandPalette.signalRed)
```

**Do not** define colour constants in individual targets. `BrandPalette` in `NoSpoilersCore` is the single source of truth for Swift. If you need a new colour, add it there first, then reference it.

### Web (GitHub Pages)

The GitHub Pages landing page in `docs/index.html` uses the palette via CSS custom properties. Keep the colour names and intent aligned with this document rather than introducing a parallel palette.

```css
:root {
  --signal-red: #ef2b2d;
  --ivory: #fff7f2;
  /* ... */
}
```

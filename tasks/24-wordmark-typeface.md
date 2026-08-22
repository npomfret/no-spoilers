# Task 24: give the wordmark a typeface of its own

**Status: BACKLOG. Raised 2026-08-22, not started.**

## Why

`NoSpoilersWordmark` is the only brand identity the app has left. The Formula One logo image was
deleted on 2026-08-13 (task 16, Phase 1) and replaced with type — `Text(Strings.AppInfo.name)`,
uppercase, `.system(size:weight: .heavy)`, tracked, in signal red. That was the right emergency
move and it worked: 4.1(a) has not been cited since. But it means the app's name is currently set in
the same face as every OS alert and Settings row on the device.

`SharedChrome.swift:104-111` is the whole of it. One `Text`, one font, two call sites.

## The correction that changes the search

**Public domain is the wrong filter.** Fonts are almost never public domain; the pool that is
(CC0) is small and thin. What we actually want is **SIL OFL 1.1**, which permits bundling in a
commercial app, requires no in-app attribution, and forbids only selling the font on its own and
reusing a Reserved Font Name. Apache-2.0 faces qualify too. So the search is "open-licensed", and
the licence text ships in the repo beside the font either way.

## The constraint that shapes it

**This is the exact surface that was rejected three times under 4.1(a) Copycats.** A typeface picked
for motorsport feel is picking back toward the thing we deleted. The rule is: distinctive without
being sport-referential.

- No obliques, no squared or clipped terminals, no speed-line or "racing" display faces.
- Check every candidate for existing motorsport-brand association before shortlisting. Being OFL is
  not the test — an open face already used in this sport's team branding is a worse choice than the
  system font, because it fails 4.1 while looking like it passed. Titillium is the obvious trap.
- The trademark disclaimer in `Strings.About.trademarkDisclaimer` is not a licence to approach the
  line.

Direction to try first: a confident editorial grotesque. `Space Grotesk` and `Archivo` (both OFL,
both with an expanded cut that carries a short all-caps wordmark) are the two to mock up. Neither
reads as motorsport.

## What it touches

- **`NoSpoilersWordmark`, and nothing else.** Not body text, not rows, not the widget's schedule
  content. One face, one component. Spreading a display face into the reading surfaces is a
  separate decision and this task does not make it.
- **`.custom(_:size:relativeTo:)` scales with Dynamic Type**, which `.system(size:)` does not. The
  wordmark is one of the three absolute-size exceptions `docs/guides/brand.md` §6 records; this
  could remove it. Confirm against the 300pt macOS popover row that `.medium` still fits — the
  measurement in `NoSpoilersWordmarkSize.fontSize` (71.5pt at 9pt system) is face-specific and will
  not survive the change. Re-measure, do not assume.
- **Registration is the real cost, and needs confirming before any font is chosen.** The font
  belongs in `NoSpoilersCore/Sources/NoSpoilersCore/Resources/` beside `Flags.xcassets`, which puts
  it in a SwiftPM resource bundle nested inside each host. `UIAppFonts` in a target Info.plist
  refers to the *main* bundle, so it is unlikely to reach a package resource — the likely answer is
  `CTFontManagerRegisterFontsForURL` once from Core against `noSpoilersCoreBundle`, which is also
  the only version that keeps three targets from each registering their own way. **The widget is a
  separate process and must register too.** Verify which mechanism actually works before committing
  to the approach; do not add a per-target Info.plist entry as a fallback if the shared one fails
  somewhere — find out why.
- **The website, or it diverges.** `docs/styles.css:92` is a system stack. Self-hosted `@font-face`
  only — no Google Fonts CDN, which is a third-party request from a page that currently makes none.
- **`docs/guides/brand.md`** §6, which is the cross-platform token spec and currently says the
  wordmark's absolute size is a deliberate exception.
- **About already has the right slot.** `Strings.About` lists `scheduleData`, `sessionData`,
  `flagIcons` — a typeface row is that existing pattern, not a new one.

## Verification

- `scripts/verify-core-tests.sh`, `verify-ios-build.sh`, `verify-mac-build.sh`,
  `verify-widget-build.sh` — the component is in Core, so all four hosts draw it.
- Screenshots on `NoSpoilers-iPhone`, because a font that is registered but not found renders as
  the system fallback and every build command still succeeds. **A green build is not evidence
  here.** Look at the pixels, on the device and in the widget.
- Re-measure the macOS popover row.

## Open

- Nothing is decided. This is a proposal to spend an hour on candidates, not an approved change.
- Sequencing: after Apple has answered on 1.1.2. Changing the wordmark while a 4.1-adjacent
  rejection is open means the next submission differs in two ways at once and neither answer is
  attributable.

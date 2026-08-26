# Task 24: give the wordmark a typeface of its own

**Status: FACE CHOSEN — Chivo Roman, 800. Decided 2026-08-26. Implementation deliberately not
started; it must not land on main until 1.1.2 has a build cut and submitted (see Sequencing).**

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

## The decision

**Chivo, roman, weight 800.** Omnibus-Type, SIL OFL 1.1, `Copyright 2019 The Chivo Project Authors`.
Six faces were set as the actual wordmark string and measured — the others were Space Grotesk,
Archivo, Archivo Expanded, Sora and Familjen Grotesk, against the shipping system `.heavy` as
baseline.

Why this one over the rest: it is built for headlines and it reads as a decision rather than as a
style, which is the property that survives three years. Space Grotesk has more character and was the
runner-up, but it is currently everywhere in tech and editorial, and a wordmark that dates is a
second one of these tasks. Sora is too close to the system font it would replace to justify the
registration cost. Archivo Expanded is the best-looking of the six and disqualifies itself on the fit
test below.

**The OFL header carries no Reserved Font Name**, so the usual RFN constraint on subsetting or
renaming does not apply here. `OFL.txt` still ships beside the font.

### Italic was considered and rejected — 2026-08-26

Asked for directly, as "a bit like the F1 style". That phrasing is the reason not to: the mark
removed from this surface on 2026-08-13 was red, italic and speed-derived, and 4.1(a) was cited
three times against it. Red + uppercase + italic in that same slot rebuilds three of that mark's
four attributes, and 4.1(a) is not a test about letterforms — it is a test about what a reviewer's
glance reads. Chivo does own a true italic (`Chivo-Italic[wght].ttf`) if this is ever revisited.
Space Grotesk and Sora have none at all, so an italic on either would be a synthesised oblique,
which the exclusion list above names first.

### Measured, in CoreText, at the shipping sizes

| face | 9pt `.medium` | 15pt `.large` | vs today |
| --- | --- | --- | --- |
| System `.heavy` (today) | 71.5pt | 117.9pt | — |
| **Chivo 800** | **65.2pt** | **113.1pt** | **−6.3pt** |
| Space Grotesk 700 | 61.4pt | 106.7pt | −10.1pt |
| Sora 700 | 69.8pt | 120.7pt | −1.7pt |
| Archivo 800 | 70.4pt | 121.7pt | −1.1pt |
| Archivo Expanded 800 | 86.1pt | 147.9pt | +14.6pt |
| Familjen Grotesk 700 | 60.1pt | 104.5pt | −11.4pt |

The harness reproduced the system font's **71.5pt** exactly, which is the figure
`NoSpoilersWordmarkSize.fontSize` records — that is why the rest of the column can be trusted.
Chivo is 6.3pt *narrower* than what ships, so the 300pt popover row gains room rather than losing
it and the `.medium` size does not have to be re-decided. Archivo Expanded's +14.6pt is what
disqualified it: the row has ~137pt for the centred Grand Prix name and it wanted 15 of them.

### The trap found while pinning the file down

`Chivo[wght].ttf` is a **variable** font whose axis is 100–900 with a **default of 500**, and its
named instances carry PostScript names of the form `Chivo-Medium_ExtraBold`. Google Fonts publishes
no static instances for this family — the directory holds only the two variable files. So
`Font.custom("Chivo", size:)` on its own resolves to Medium, not 800, and whether
`.fontWeight(.heavy)` drives the `wght` axis on a registered variable font is an empirical question
that has not been answered here. **Answer it before writing the view**, and expect the fallback to
be building the font from a `CTFontDescriptor` carrying `kCTFontVariationAttribute` — which is what
the measurement harness did, and what produced every number in the table above.

## What it touches

- **`NoSpoilersWordmark`, and nothing else.** Not body text, not rows, not the widget's schedule
  content. One face, one component. Spreading a display face into the reading surfaces is a
  separate decision and this task does not make it.
- **`.custom(_:size:relativeTo:)` scales with Dynamic Type**, which `.system(size:)` does not. The
  wordmark is one of the three absolute-size exceptions `docs/guides/brand.md` §6 records; this
  could remove it. The face-specific measurement in `NoSpoilersWordmarkSize.fontSize` has been
  re-taken — 71.5pt at 9pt system becomes **65.2pt at 9pt Chivo 800** — but that was measured at a
  fixed size. If the wordmark starts scaling with Dynamic Type, the popover row has to be checked
  again at the accessibility sizes, which is a question the current absolute size never had to
  answer.
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

## Sequencing — read before starting

**This must not be in build 10009.** 10009 is the binary for the 1.1.2 resubmission, which is a
clean single-variable answer to 4.2.2: new device capabilities, nothing else moved. The wordmark is
the surface with 4.1(a) history. If both change in one submission and the answer is bad, neither
change is attributable.

So the order is: cut 10009 → attach it → submit 1.1.2 → *then* implement this on main. Because the
repo works on main only, starting the implementation early is the same thing as shipping it early.

## Open

- The `wght`-axis question above — whether `.fontWeight()` reaches a registered variable font, or
  whether a `CTFontDescriptor` is required. This decides what the view looks like.
- Whether the widget process needs its own registration call or inherits nothing. The task assumes
  it needs its own; that has not been proven.
- One last check for motorsport-brand use of Chivo before it ships. Nothing was found, but a search
  is not a proof, and this is the surface where that distinction has already cost three rejections.

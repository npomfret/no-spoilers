# Task 24: give the wordmark a typeface of its own

**Status: DONE — 2026-08-26.** Chivo ExtraBold ships in Core, in all three hosts and on the
website. Verified by pixels on `NoSpoilers-iPhone`, by four green wrappers, and by four new tests.
The sequencing worry below was resolved rather than waited out: TeamCity pins a queued build's
revision at queue time, so build 10009 was already fixed to `27651d1` and could not pick this up.

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

### The trap found while pinning the file down — and how it was answered

`Chivo[wght].ttf` is a **variable** font whose axis is 100–900 with a **default of 500**, and its
named instances carry PostScript names of the form `Chivo-Medium_ExtraBold`. Google Fonts publishes
no static instances for this family — the directory holds only the two variable files. So
`Font.custom("Chivo", size:)` on its own resolves to Medium, not 800.

**Answered empirically on 2026-08-26, before the view was written.** Registering the file and asking
CoreText for each spelling of the name, measuring "NO SPOILERS" at 15pt with 1.4 tracking:

| asked for | measured | resolved to |
| --- | --- | --- |
| family `"Chivo"` | 111.4pt | `Chivo-Medium_Regular` |
| `"Chivo-Medium_ExtraBold"` | **113.1pt** | `Chivo-Medium_ExtraBold` |
| `CTFontDescriptor` with `wght` 800 | 113.1pt | `Chivo-Medium_ExtraBold` |

The named instance and the descriptor agree exactly, so **the descriptor was not needed** — which
is what keeps `BrandTypeface` free of a `UIFont`/`NSFont` conditional and lets the view stay on
plain `Font.custom`. The 1.7pt gap between Medium and ExtraBold is the whole hazard: invisible in a
screenshot, and enough to make every measurement in `NoSpoilersWordmarkSize` wrong.

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

## Sequencing — resolved 2026-08-26, not waited out

The worry was real: 10009 is the binary for the 1.1.2 resubmission, a clean single-variable answer
to 4.2.2, and the wordmark is the surface with 4.1(a) history. Two changes in one submission and
neither answer is attributable. Because the repo works on main only, starting the implementation
looked like the same act as shipping it.

**It is not, and the queue proves it.** TeamCity pins a queued build's revisions when the build
enters the queue, not when an agent picks it up. Build 944 (`Publish iOS`) and its gating Verdict
943 both reported `27651d1`, and `8a29a3f` — committed *after* they queued — was already excluded.
So anything committed from that point cannot reach 10009, and this work went ahead the same day.

**It still ships in 1.1.3, not 1.1.2.** Nothing here changes that; it changes only when the code
could safely be written.

## What was built

- **`BrandTypeface.swift`** in Core — the face, the licence reasoning, and the only registration.
  Lazy `static let`, so each host process registers once on the first wordmark it draws and no
  entry point has to remember. `preconditionFailure` if the face is missing or resolves to
  something else, because `Font.custom` substitutes silently and every build still goes green.
- **`Chivo.ttf` + `Chivo-OFL.txt`** in `Resources/`, reaching every host through the package's
  existing `.process("Resources")` rule — the same door `Flags.xcassets` uses. No `UIAppFonts`
  entry anywhere, and no per-target registration.
- **`NoSpoilersWordmark`** now asks `BrandTypeface`. It is the only Swift call site.
- **A Typeface row in About**, beside schedule data, session data and flag icons. The OFL asks for
  no attribution; it is there because the other three borrowed things are.
- **The website**: `--wordmark` token and a self-hosted `@font-face` in `docs/styles.css`, applied
  to `.hero h1` only. `privacy.html`'s heading stays in the system font — one face, one component,
  on both sides. Self-hosted rather than Google's CDN because it would otherwise be the only
  third-party request either page makes.
- **`docs/guides/brand.md` §6**, which said "Swift-only" and is now a two-sided binding.

## Verification — 2026-08-26

- `scripts/verify-core-tests.sh` — 102 tests, up from 98. Four are new `BrandTypefaceTests`, and
  they exist because this is the one change whose failure mode is invisible: they pin that asking
  for the wordmark registers the face, that the name resolves heavier than the family default, that
  9pt still measures 65.2pt, and that both the font and its licence reach the bundle.
- `scripts/verify-ios-build.sh`, `verify-widget-build.sh`, `verify-mac-build.sh` — all pass.
- **Pixels on `NoSpoilers-iPhone`** — the app header photographed on the simulator, Chivo rendering
  beside an SF label for comparison. This was the check the task insisted on, and it needed the app
  built *without* `CODE_SIGNING_ALLOWED=NO`: that flag strips the entitlements, the App Group
  container then never exists, and `screenshots.py` fails at `get_app_container` with exit 117.

## Still open

- **The macOS popover has not been photographed.** It is proven by a green build and by the Core
  tests, which run in a macOS process and register the font from the same bundle — but not by
  pixels. `mac_screenshots.py` quits whatever is in the menu bar and launches the app it is given,
  so it takes the machine's menu bar over for the duration; that was not worth doing unasked while
  the shipped macOS app is live. The fit risk it would check is the one direction that cannot hurt:
  Chivo is 6.3pt narrower than what the row already tolerated.
- **The widget never draws the wordmark**, so it never registers the face — the two call sites are
  the iOS and macOS content views. The lazy registration makes that automatically correct rather
  than something to remember. The task had assumed the widget would need its own call; it does not.
- One last check for motorsport-brand use of Chivo before it ships. Nothing was found, but a search
  is not a proof, and this is the surface where that distinction has already cost three rejections.

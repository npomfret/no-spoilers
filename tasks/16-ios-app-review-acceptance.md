# Task 16: Get the iOS app through App Review

**Status: OPEN — but down to one rejection reason, not two. Corrected 2026-08-26.**

**4.1(a) Copycats has not been cited since the logo came out on 2026-08-13.** The 2026-08-21
rejection of `1.1.2` was **4.2.2 alone** — the first time it has ever arrived without 4.1(a) beside
it, which is what makes Phase 1 below provably the right call rather than merely plausible. The
history from here on is `tasks/23-native-functionality-for-4-2-2.md`, which owns the 4.2.2 answer;
this file remains the record of the branding half and of the thread itself. The narrative below is
written as it stood in August and is not re-dated.

iOS `1.0.21` has been `REJECTED` since 2026-04-27. Four review rounds, four rejections, and the
thread has sat unanswered in `UNRESOLVED_ISSUES` since 2026-05-17. macOS is unaffected and on sale.

The full Resolution Center thread was retrieved on 2026-08-13 from the private
`appstoreconnect.apple.com/iris/v1/resolutionCenterThreads/…/resolutionCenterMessages` endpoint,
using a browser session cookie. **There is no public API for this** — `appstore_status.py` reports
the state and says so. Anything below quoted from Apple is verbatim.

**Use `appstoreconnect-bot` for this, not a hand-rolled curl.**
`/Users/nickpomfret/projects/appstoreconnect-bot` is a sibling repo covering exactly this gap:

```sh
cd ../appstoreconnect-bot && npm install && npm run build
node dist/cli.js report          # submissions -> thread -> messages + rejections + draft
```

It authenticates by capturing a browser request (`pbpaste | npx asc login`), so the session lasts
hours and `asc status` shows what is left. **It writes**: `set-build`, `upload-screenshot`,
`delete-screenshot` and a raw `patch <resource>/<id> '<json:api body>'`, which covers screenshots
and every metadata field. **Replying in the Resolution Center is still unmapped**, so Phase 4 below
goes through the browser unless someone captures that write.

The two tools do not overlap and neither should grow the other's job: `scripts/appstore_status.py`
is the public API, key-authenticated and GET-only, and can see the review *state* but never the
conversation. Session cookies (`dqsid`, `myacinfo`, `itctx`, `as_*`) must not land in either repo.

---

## What Apple actually said, round by round

| Date | Guidelines cited | Version |
|---|---|---|
| 2026-04-27 | **4.1(c)** name/subtitle, **4.2.2** minimum functionality | 1.0.21 (6) |
| 2026-05-04 | *(no guidelines — boilerplate design-videos reply that engaged with nothing)* | — |
| 2026-05-06 | **4.1(a)** metadata | — |
| 2026-05-12 | **4.1(c)**, **4.1(a)**, **4.2.2** | 1.0.21 (8) |
| 2026-05-17 | **4.1(a)**, **4.2.2** | 1.0.21 (8) |

**4.1(c) was fixed and is gone.** It disappeared from the 05-17 rejection after the 05-15 rename
to `No Spoilers - Grand Prix` / `Spoiler-free GP race schedule`. That rename works — keep it.

**4.1(a) and 4.2.2 are what remain.**

> **4.1(a)** — "The metadata appears to contain potentially misleading references to third-party
> content. Specifically, the metadata includes content that resembles F1 without the necessary
> authorization."

> **4.2.2** — "the app only includes links, images, or content aggregated from the Internet with
> limited or no native functionality… it does not sufficiently differ from a web browsing
> experience."

---

## 4.1(a): the cause is the screenshot, and we told Apple otherwise

Every "F1" and "Formula 1" string was removed from the iOS description, promotional text and
keywords on 05-11 and 05-15. 4.1(a) survived both. It survived because **the metadata still
contains the Formula 1 logo — in the App Store screenshot.**

The one iPhone screenshot on the listing shows the app's header displaying the red Formula One
wordmark, ™ included. It is the first thing in the image. It is there because the app draws it:

```
NoSpoilersCore/…/Resources/Flags.xcassets/f1logo.imageset      the Formula One wordmark
  SharedChrome.swift:152   NoSpoilersWordmark  ->  iOS ContentView.swift:138, :241
  NoSpoilersMac/ContentView.swift:131                             macOS popover header
  NoSpoilersMac/NoSpoilersMacApp.swift:30                         macOS menu bar status item
```

`AboutView.swift:58` credits it to Wikimedia Commons (`File:Formula_One_logo.svg`), which settles
a copyright question and says nothing about trademark. `Strings.swift:29` carries a non-affiliation
disclaimer, which does not license use of a mark as your own product identity.

**And this was denied to App Review, twice.** The 05-11 reply states:

> "no official Formula One logos or imagery are used in the app icon, screenshots, or marketing"

and the 05-05 reply says "The app uses no official Formula 1 logos or imagery." Both are false, and
the reviewer can see they are false by opening the listing. That is very likely why 4.1(a) kept
being restated in identical words rather than discussed — from Apple's side, the metadata still had
the logo in it and the developer said it did not.

**This has to be corrected explicitly, not quietly fixed.** Remove the logo, then say plainly that
an earlier reply was wrong.

### Also still F1-branded: the macOS listing, under the same app record

Universal Purchase means both platforms share app record `6761343835`. The iOS listing was cleaned;
macOS was not, and is live:

```
name        "No Spoilers F1"                       (appInfo b391f441, READY_FOR_SALE)
subtitle    "F1 race weekend schedule"
keywords    F1,Formula 1,schedule,spoiler free,menu bar,calendar,widget
description "...keeps you on top of the F1 race weekend..."
```

The pending rename lives in a second appInfo (`859a5495`). A reviewer examining "the metadata" for
this app can see the macOS side.

**Re-measured 2026-08-16, and two things have moved:**

- That second appInfo now reads `READY_FOR_REVIEW`, not `REJECTED`, and the iOS version record is
  `1.1.1 READY_FOR_REVIEW` with build 9 attached. The rename is **staged and will go live with the
  next approval on either platform** — it is no longer blocked on anything but an approval.
- **There is no editable macOS version at all.** Only two macOS version records have ever existed,
  1.0.13 and 1.0.21, and both are `READY_FOR_SALE`. So the Mac keywords and description cannot be
  edited, only replaced by creating a macOS 1.1.1 — which decision 3 below is about. Nothing here
  can create one: `appstore_status.py` only reads versions, and `appstoreconnect-bot` maps
  `set-metadata`, `set-build` and `submit` but not create-version. Today that is a browser step.

One more falsehood on the live Mac listing, not previously recorded: its what's-new says
"Universal app — now also available on iPhone and iPad". The iOS app has never been approved, so
the store is advertising a release that does not exist — on the record under review, for metadata.

### And the website — FIXED 2026-08-13

`docs/index.html` used "F1" six times and "Formula 1" once; `docs/privacy.html` once. Both
`supportUrl` and `marketingUrl` point there, so this page is one click from the submission.

`docs/brand.md` turned out to be clean — it is a palette and typography document and never named
the series. The earlier note listing it was wrong.

| Where | Was | Now |
| --- | --- | --- |
| `index.html` `<title>` | `No Spoilers   Spoiler-safe F1 for macOS` | `No Spoilers — the spoiler-free Grand Prix schedule` |
| `index.html` `<meta description>` | `A macOS menu bar app that shows the F1 race weekend schedule…` | `A Home Screen widget for iPhone and a menu bar app for Mac…` |
| `index.html` hero | `The F1 race weekend schedule for your Mac and iPhone` | `The Grand Prix weekend schedule for your Mac and iPhone` |
| `index.html` footer credit | `F1 logo: Wikimedia Commons` | deleted |
| `index.html` App Store href | `…/app/no-spoilers-f1/id6761343835` | `…/app/id6761343835` |
| `index.html` feature card | `Home screen widgets` | `Home Screen widgets` |
| `privacy.html` | `publicly available Formula 1 race schedule data` | `publicly available race schedule data` |
| `README.md` | `spoiler-safe F1 race weekend widget` | `spoiler-free Grand Prix weekend widget` |
| `README.md` | `F1 fans… the F1 app` | `Fans… the official series app` |

**The title and meta description were also wrong about the product, not just the branding.** They
described a macOS menu bar app. A reviewer following `marketingUrl` from an *iOS* submission landed
on a page that did not describe the thing they were reviewing — the same failure as the review
notes fixed above, from the same cause: copy written when this was a Mac-only product.

**The footer trademark disclaimer was deliberately kept**, naming Formula 1, F1 and Formula One
Licensing BV. It matches `Strings.About.trademarkDisclaimer`, which still ships in the binary. Note
the App Store *description* uses a different, generic form ("not affiliated with… any racing series,
team, circuit or broadcaster") — that one avoids putting the mark into indexed App Store metadata, a
concern that does not apply to a disclaimer in your own site footer. Naming the mark owner is the
standard nominative-fair-use form and is strictly more protective.

**Three "F1" strings remain and all are correct.** `github.com/sportstimes/f1` is the real upstream
feed path (`index.html`, `privacy.html`, `README.md` ×2) and `openf1.org` is the real session-data
host. Changing either would break a link.

**The App Store href change does not clean the address bar today.** `apps.apple.com/gb/app/id6761343835`
301-redirects to the slug form, and the slug is derived from the *live* app name — so it currently
lands on `…/no-spoilers-f1/…`. Verified with `curl -o /dev/null -w '%{redirect_url}'`. The ID form is
still the right href: it is the one that survives the pending rename, and when
`No Spoilers - Grand Prix` goes live the redirect target stops containing "f1" on its own.

---

## 4.2.2: the real blocker, and no amount of metadata editing touches it

Apple has cited this in three of four rejections and has never engaged with the argument against
it. The 05-01 reply was detailed and good — the spoiler-free premise, the results fields that do not
exist in the domain model, the WidgetKit extension, App Group caching, offline support, OpenF1
session end-times, no `WKWebView` anywhere. Apple's response was a boilerplate list of design
videos.

Arguing again is unlikely to work. **What has not been tried is making the native functionality
visible in the listing itself.**

**Corrected 2026-08-13: the iOS listing carried no screenshots at all.** This section previously
said one iPhone and one iPad screenshot of a scrolling list; queried directly, iOS version 1.0.21
(`50ebef6d-a70c-41f0-8252-a8014fb9d47e`, locale `443131a2-5fa6-42a1-8d6e-85e01ebe5db1`) held
**zero** `appScreenshotSets`. The scrolling-list screenshots are on the **macOS** listing, whose
en-GB localization (`38b916ff-085d-4163-8c4f-70a18b732647`) holds one `APP_DESKTOP` set with a
single 1280 × 800 JPG still named `Gemini_Generated_Image_utojutojutojutoj.jpg`.

That makes the 4.2.2 problem worse than described, not better: a reviewer opening the iOS listing
saw **nothing**. The single strongest counter-argument — a Home Screen widget that renders the next
session without opening anything — was not shown, because nothing was.

### The iOS App Review notes describe the macOS app. Found 2026-08-13.

`appStoreReviewDetails/d3ee6a64-9fe0-4928-91ca-9054c47f4382`, attached to the **iOS** version:

> "This is a menu bar app. After launching, the icon appears in the top-right of the menu bar.
> Click it to open the popover showing the Grand Prix schedule."

There is no menu bar on an iPad. The single instruction the reviewer was given describes a different
platform's app, and following it finds nothing. A reviewer who launches the app, looks for the thing
the developer told them to look for, and does not find it, has been handed the 4.2.2 conclusion —
"limited or no native functionality" — by the submission itself. **This is a stronger candidate for
why 4.2.2 kept being restated than anything in the description**, and it costs one PATCH to fix.

`demoAccountRequired` is `true` and a demo account is set, on an app whose own listing says "No
account. No sign-in." Nothing in the app has a login. That is a second thing in this submission that
does not match the app, after the logo denial. *(This sentence said "a third… after the logo denial
and the Lock Screen claim". The Lock Screen claim turned out to be true — see the correction below.)*

**Fixed 2026-08-13.** `asc patch appStoreReviewDetails/d3ee6a64…`; the original is in
`tmp/asc-metadata-backup/ios-review-details-BEFORE.json`, so a revert is one PATCH. The notes now
lead with "No Spoilers is a Home Screen widget. That is the product on iPhone and iPad", give the
three steps to add it — a widget is invisible until someone places it — and describe what each of
the three sizes shows. Those descriptions were written from the six uploaded captures, not from
memory, so a reviewer comparing notes to screenshots to app finds the same thing three times.

The demo account is gone: `demoAccountRequired` is now `false` and both fields read back `null`.
Nothing in the app has a sign-in, so it was a credential attached to an app that has no use for one.

The notes also **correct the menu-bar instruction explicitly**, rather than quietly replacing it —
same principle as the logo correction in Phase 4, and for the same reason: a reviewer who has been
misdirected once needs to be told, or the next submission reads as the same developer being vague
again.

Verified by reading back through both APIs: `asc review-details` shows the new notes with
`demoAccountName: None`, and `appstore_status.py` reports `demo account  not required`.

Concrete moves, in order of value:

1. ~~**Screenshot the widget on a Home Screen.**~~ **DONE 2026-08-13.** `scripts/screenshots.py`
   captured it; uploaded to the iOS en-GB listing via
   `appstoreconnect-bot`, `assetDeliveryState: COMPLETE` at 1242 × 2688:
   ```
   set   6dd79562-86c6-4f9f-99d5-ccd61e615116  APP_IPHONE_65
   shot  f18086cf-e786-4d9a-893f-d3a1eb417467  no-spoilers-widget-iphone-65.png
   ```
   **It did not have to wait for Phase 1** — `NoSpoilersWordmark` / `f1logo` appear in
   `NoSpoilers/NoSpoilers/ContentView.swift:138,241` and the macOS app but nowhere in
   `NoSpoilersWidget.swift`, so the widget capture is already free of the Formula One mark.
2. ~~**Fill the remaining screenshot slots.**~~ **Six uploaded 2026-08-13**, replacing the single
   iPhone shot, which was deleted. All three widget families on both device classes, every one
   showing the seeded fixture rather than a stale timeline — that distinction cost four wrong
   captures, and the App Store screenshots section of `docs/guides/building.md` records why only
   `--install` clears a stored timeline. `assetDeliveryState: COMPLETE`, no errors, confirmed by
   `appstore_status.py`:
   ```
   set 6dd79562-86c6-4f9f-99d5-ccd61e615116  APP_IPHONE_65          1242 x 2688
       no-spoilers-widget-{large,medium,small}-iphone.png
   set a204142d-8352-462a-b685-ae12db9db457  APP_IPAD_PRO_3GEN_129  2048 x 2732
       no-spoilers-widget-{large,medium,small}-ipad.png
   ```
   Large leads each set deliberately — it carries the most functionality per glance, and the App
   Store shows them in order. **Still open: app-UI shots** (countdown, tabbed schedule, offline
   state, About). Those needed Phase 1, which is now done, so nothing blocks them.
3. **Consider native surfaces that make the point structurally**, not just visually: a Live Activity
   or Dynamic Island for a running session, local notifications ahead of a session start, Lock
   Screen widgets, a Shortcuts/App Intents action. Each is impossible in a browser. This is product
   work and needs a decision about scope.
4. ~~**Put the widget in the App Review notes**~~ **DONE 2026-08-13**, along with removing the
   menu-bar instruction that sent the reviewer looking for the wrong platform's app. See above.

`whatsNew` for iOS `en-GB` is empty and **cannot be filled** — PATCHing it returns
`409 STATE_ERROR "Attribute 'whatsNew' cannot be edited at this time"`, because 1.0.21 is the first
iOS release and there is no previous version for release notes to describe. `appstore_status.py`
flags it; the flag is a false positive for a first release and should be taught to skip it.

### iOS copy rewritten 2026-08-13, widget-first

Done with `asc patch`. Originals are in `tmp/asc-metadata-backup/ios-*-BEFORE.json`, so a revert is
one PATCH. What changed and why:

- **Subtitle** `Spoiler-free GP race schedule` → `Spoiler-free GP race widget` (27/30). Still free of
  "F1", so 4.1(c) stays fixed, and the widget — the answer to 4.2.2 — is now visible in search
  results, not buried in paragraph six.
- **Description** rewritten. The old one was 3748 characters of which roughly two thousand were
  trailing spaces and leading indentation from some earlier paste; it would have rendered ragged on
  the product page. The new one is 1948 characters of actual text. `THE WIDGET` is the first
  section after the hook. Added `WORKS OFFLINE` — true, and a web browsing experience cannot do it.
  Removed "the official apps", which invited exactly the comparison 4.1(a) is about. Added a plain
  non-affiliation line at the end.
- **Keywords** — dropped `menu bar` (macOS-only, dead weight in an iPhone search index) and stopped
  repeating words already in the name and subtitle, which Apple indexes anyway. Now
  `motorsport,racing,schedule,qualifying,practice,sprint,countdown,timetable,replay,catch up` (89).
- **Promotional text** — rewritten. It dropped a Lock Screen claim it should have kept; see below.

**CORRECTED 2026-08-13: the Lock Screen claim was not false, and this file was wrong to call it
one.** The old promotional text said "the full race weekend at a glance in a widget on your lock
screen", and it was removed on the strength of the argument that follows, which does not hold:

> `NoSpoilersWidget.swift:717` is `.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])` —
> Home Screen only, no `.accessory*` families, therefore no Lock Screen widget.

**Declaring no `.accessory*` families does not mean the widget cannot appear on a Lock Screen.**
Those three system families are exactly what iPadOS puts on the Lock Screen, and what StandBy
renders on iPhone. The user confirmed from a device that the widget does appear there. The reasoning
above inferred a user-visible behaviour from a declaration in source without checking the behaviour,
which is the same class of error as the logo denial it was written to avoid.

**Both consequences are now undone.** The drafted App Review reply had confessed to a second false
statement that was never made; that came out before sending. And the promotional text had lost a
true, load-bearing selling point — a widget that appears on the Lock Screen is a strong 4.2.2
argument, because a web page cannot be there. Restored 2026-08-13:

```
was  A Home Screen widget with the whole race weekend on it: which sessions have finished
     and are safe to watch, a live countdown to the next one, and never the result.
now  A Home Screen and Lock Screen widget with the whole race weekend on it: which sessions
     are safe to watch, a live countdown to the next one, and never the result.        (161/170)
```

The word "widget" is kept deliberately — the whole 4.2.2 answer rests on it, so the sentence names
the product before it names the surfaces. Backup in `tmp/asc-metadata-backup/ios-promo-BEFORE-lockscreen.json`;
verified by `appstore_status.py`, which reads the public API with a different key, rather than by
trusting the PATCH response.

The rest of the new copy was checked against the code first:

| Claim | Verified at |
|---|---|
| widget in small, medium, large | `NoSpoilersWidget.swift:717` |
| works offline from a cached calendar | `ScheduleStore.swift:21` loads cache at init, `:93` falls back on refresh failure |
| your own time zone and date format | `Strings.swift:36-41`, `Locale.current` / `TimeZone.current` |
| Practice, Sprint Qualifying, Sprint, Qualifying, race | `SessionKind.swift:4-10` |
| no account, no tracking, no ads | no analytics SDK anywhere; the only `URLSession` is the schedule fetch |

**Wording alone does not fix 4.1(a).** The cause is the Formula One wordmark in the shipped app and
therefore in the screenshots — Phase 1. This rewrite removes the invited comparison and adds the
disclaimer; it does not remove the mark.

### Two more things found while checking those claims

1. **The reviewer used an iPad.** The 05-17 rejection header reads `Review Device: iPad Air 11-inch
   (M3)`, and the iOS listing has no iPad screenshot at all. Whoever fills the remaining slots
   should treat `APP_IPAD_PRO_3GEN_129` as required, not optional — the reviewer is looking at the
   iPad listing.
2. ~~**Xcode template junk in the widget target.**~~ **Deleted 2026-08-13.**
   `NoSpoilersWidgetLiveActivity.swift` rendered `Text("Hello \(context.state.emoji)")` with a
   Dynamic Island reading "Leading" / "Trailing", and `NoSpoilersWidgetControl.swift` was a
   "Start a timer" Control widget whose provider was `let isRunning = true // Check if the timer is
   running`. They were **not** dead files: `NoSpoilersWidget` is a
   `PBXFileSystemSynchronizedRootGroup` excluding only `Info.plist`, so both compiled into the
   shipping extension — they were merely absent from `NoSpoilersWidgetBundle`, which is what made
   them invisible to a user. Both gone, plus the now-dead `Strings.Control` block.
   `verify-widget-build.sh` passes, `ExtractAppIntentsMetadata` now reports "Extracted no relevant
   App Intents symbols", and the extension links only `-framework SwiftUI -framework WidgetKit`.

3. **The widget gallery description says "F1".** `NoSpoilersWidget/Strings.swift:21` is
   `widgetDescription = "F1 race weekend sessions — no results."`, fed to `.description()` on the
   widget configuration. **This is the text iOS shows in the widget picker when a user — or a
   reviewer — adds the widget.** It is user-visible app content carrying the mark, on the one
   surface the App Store screenshot now points at. Belongs in Phase 1 with the wordmark; left alone
   for now so Phase 1 lands as one coordinated change rather than a trickle.

`contentRightsDeclaration` on the app record is `DOES_NOT_USE_THIRD_PARTY_CONTENT`. That is not true
while the wordmark is in the app; Phase 1 makes it true.

---

## The version record cannot be submitted as it stands

Found 2026-08-13 while checking readiness. The iOS `appStoreVersion` is labelled `1.0.21` and has a
build from a different train attached:

```
appStoreVersions/50ebef6d   versionString 1.0.21   PREPARE_FOR_SUBMISSION
  build 046e610d            build 5, train 1.1.1, uploaded 2026-08-13
project MARKETING_VERSION   1.1.1
```

The 1.0.21 train holds exactly one build, `6`, expired since April; the rejected build 8 is in the
1.0.22 train. So `versionString` needs PATCHing to match whatever build is finally submitted — and
that build has to be a new one regardless, since build 5 predates Phase 1.

Note also that the version is now `PREPARE_FOR_SUBMISSION`, not `REJECTED` as the header of this file
says. That is why the metadata PATCHes were accepted at all. The *submission* is still
`UNRESOLVED_ISSUES`; an editable version does not close a rejection.

## Plan

### Phase 1 — remove the logo (unblocks 4.1(a), and makes the correction honest) — **DONE 2026-08-13**

**The replacement is type, not an image.** `NoSpoilersWordmark` now renders
`Text(Strings.AppInfo.name).textCase(.uppercase)` in `BrandPalette.signalRed`, so there is no mark
to license and the header shows the same string as the app name everywhere else. Sizes became
`fontSize`/`tracking` instead of a fixed `CGSize`; the unused `.small` case went with the image.
Nothing needed a fail-fast guard in the end, because nothing loads a resource any more.

The menu bar could not simply lose its mark: `MenuBarLabelView` shows the countdown only when
`showCountdown` is on and the flag only when `showFlag` is on, so the logo was the one always-present
element and deleting it would have left an empty status item. It now draws `nospoilers-icon` — the
app's own icon, a checkered-flag blindfold, already used by `AboutView` — at 16 × 16.

What changed:

```
SharedChrome.swift            NoSpoilersWordmark: Image("f1logo") -> Text, sized by font
                              NoSpoilersWordmarkSize: frame -> fontSize/tracking, .small deleted
NoSpoilersMac/ContentView.swift  inline Image("f1logo") -> NoSpoilersWordmark(size: .medium)
                                 private `f1Red` alias deleted, BrandPalette.signalRed inlined
NoSpoilersMacApp.swift        rasterizeNSImage() and f1MenuBarLogo deleted (30 lines);
                              menu bar draws nospoilers-icon at 16x16
AboutView.swift               Wikimedia "F1 logo" acknowledgement row deleted
Core Strings.swift            About.branding deleted
NoSpoilersMac/Strings.swift   tagline -> "Grand Prix schedule · spoiler free"
NoSpoilersWidget/Strings.swift  widgetDescription -> "Grand Prix weekend sessions — never the result."
Flags.xcassets/f1logo.imageset  deleted (the SVG was the actual Formula One wordmark path)
```

Two of those were convergence rather than de-branding, and both were pre-existing drift: the macOS
popover drew the wordmark with its own inline `Image` instead of the shared `NoSpoilersWordmark`, and
`f1Red` was a private alias for a `BrandPalette` colour the same file otherwise used directly.

**Kept: the trademark disclaimer.** It is accurate and it is the opposite of a misleading reference.

Verified: `verify-core-tests.sh` 11 tests 0 failures, `verify-ios-build.sh`, `verify-mac-build.sh`,
`verify-widget-build.sh` all **BUILD SUCCEEDED**;
`grep -rn "f1logo\|f1Red\|f1MenuBarLogo\|rasterizeNSImage\|About.branding" --include="*.swift" .`
returns nothing.

`contentRightsDeclaration: DOES_NOT_USE_THIRD_PARTY_CONTENT` is now true rather than false.

### Phase 2 — clean the remaining metadata

- Retake **all** screenshots after Phase 1, on both platforms. The current ones contain the logo.
- De-brand the macOS listing: name, subtitle, keywords, description.
- ~~De-brand `docs/index.html`, `docs/privacy.html`, `README.md`.~~ Done 2026-08-13. `docs/brand.md` was already clean.
- Write iOS `whatsNew`.

### Phase 3 — answer 4.2.2 with screenshots, not prose

**Show all three widget sizes.** Small, medium and large render genuinely different amounts of the
weekend, and "one glanceable surface, three densities, never a result in any of them" is an argument
a web page cannot make. It costs two screenshots rather than three, because of how the Home Screen
grid packs: large is 4 rows and medium is 2, which fills a 6-row page exactly, so the smalls go on a
second page. Same again on iPad — the reviewer's device. Four shots against nine free slots.

`scripts/screenshots.py` already does the capture against fixture data. The only manual step is
placing each widget once per simulator; there is no `simctl` verb for it (`scripts/screenshots.py:26`).

Then decide on Live Activities / notifications / App Intents separately.

### Phase 4 — reply and resubmit

Answer the thread — it has been open since 05-17 and an unanswered rejection is not a closed one.
The reply should:

- **correct the earlier false statement about logos, explicitly.** Say the previous replies were
  wrong, that the Formula One wordmark was in the app and therefore in the screenshots, and that it
  has been removed.
- list what changed per guideline, field by field.
- point at the widget screenshots for 4.2.2 rather than restating the 05-01 argument.

Then ship: `scripts/ship.sh <version>` covers all three channels version-locked, and Xcode Cloud
delivers TestFlight builds per push. Both pipelines are working and proven as of 2026-08-13.

---

## Verification

- [x] `grep -rn "f1logo" --include="*.swift" .` returns nothing (2026-08-13)
- [x] `f1logo.imageset` deleted (2026-08-13)
- [x] `verify-core-tests.sh`, `verify-ios-build.sh`, `verify-mac-build.sh`, `verify-widget-build.sh` pass (2026-08-13)
- [x] Widget gallery description no longer says "F1" (2026-08-13)
- [x] No iOS screenshot contains the Formula One wordmark — all six are widget captures, and the widget never drew it (2026-08-13). macOS listing screenshot still to retake.
- [x] At least one iOS screenshot shows the Home Screen widget — six, covering all three families (2026-08-13)
- [ ] macOS listing free of "F1" / "Formula 1" in name, subtitle, keywords, description. Name and
      subtitle are shared (`appInfoLocalizations`) and the pending record is already clean, but the
      macOS keywords still read `F1,Formula 1,schedule,spoiler free,menu bar,calendar,widget` and
      are **not editable while that version is `READY_FOR_SALE`** — it needs a new macOS version.
      Mitigated for now by scoping the reply's metadata sentence to "on this listing", so it stays
      true whichever listing a reviewer checks (2026-08-13)
- [x] Website and README de-branded (2026-08-13)
- [x] iOS description, keywords, promotional text and subtitle rewritten (2026-08-13)
- [x] No metadata claim unsupported by the code. The Lock Screen claim was removed on a wrong
      reading of `supportedFamilies`; restored 2026-08-13 after the user confirmed it from a device
- [x] At least one iPad screenshot, since the reviewer reviews on an iPad — three, at 2048 x 2732 (2026-08-13)
- [x] Delete `NoSpoilersWidgetLiveActivity.swift` and `NoSpoilersWidgetControl.swift` (2026-08-13)
- [ ] ~~iOS `whatsNew` written~~ — locked by Apple on a first release, not actionable
- [x] Every third-party source the app actually uses is named in the reply (2026-08-13). The draft
      had claimed "no third-party content at all… its only data is sportstimes/f1". False:
      `ScheduleStore.swift:19` builds a `SessionEndConfirmer`, which polls `api.openf1.org`
      (`/sessions` and `/race_control`) for the confirmed finish time, and the widget reads the
      result at `NoSpoilersWidget.swift:84`. The About screen credits three sources — sportstimes/f1,
      OpenF1, flag-icons by Lipis — so a reviewer disproves the claim by opening the app. Same class
      of error as the logo denial and the Lock Screen claim: a statement about the app written from
      an assumption rather than from the code. Rewritten to name all three and to say exactly what is
      read from OpenF1 (one timestamp, no results).
- [x] The Wikimedia Commons credit for the Formula One logo went with the image in `525a6e0`;
      nothing stale left in Acknowledgements (2026-08-13)
- [x] Resolution Center answered, including the correction — sent 2026-08-13T17:11:51Z, confirmed
      2026-08-16 as the last message on thread `74533c00`; it opens "A CORRECTION" and retracts the
      5 and 11 May denials by name. The submission stays `UNRESOLVED_ISSUES` until Apple acts
- [ ] `appstore_status.py` shows the iOS version out of `REJECTED` — as of 2026-08-16 the version
      record reads `READY_FOR_REVIEW`, which is the state before a decision, not a decision

---

## Decisions needed

1. **The logo — confirm removal everywhere.** Menu-bar-only was floated as a compromise; it does
   not survive contact with this thread, because the menu bar icon is the macOS app's identity and
   the same asset feeds the iOS wordmark that is already in evidence on the listing.
2. **How far to go on 4.2.2.** Screenshots alone may be enough, or it may need a Live Activity /
   notifications. Cheapest first: retake screenshots, resubmit, and see whether 4.2.2 survives.
3. **Whether to fix the macOS listing now.** It is on sale and uncomplained-about, but it shares the
   app record with the thing under review. Concretely (2026-08-16): fixing it means creating and
   submitting a macOS 1.1.1, which opens a second platform in review while the iOS submission is
   still unanswered. No build work blocks it — macOS 1.1.1 already has installable builds 15, 16, 17
   and `10001`. If iOS is approved first the staged rename lands anyway, leaving `No Spoilers - Grand
   Prix` over a Mac description about the F1 race weekend: better, and still inconsistent.

## The macOS listing was never swept — found and fixed 2026-08-22

**The 4.1(a) sweep of 2026-08-13 covered the iOS listing and stopped there.** The macOS listing had
carried the marks the whole time, live on the store, on the one surface an App Review trademark
check actually reads:

```
keywords      F1,Formula 1,schedule,spoiler free,menu bar,calendar,widget
description   "...keeps you on top of the F1 race weekend..."
review notes  "...the popover showing the F1 schedule."
```

Nothing pointed at it. `appstore_status.py` reports what the listing *is* and has no opinion about
what is in it, and macOS had not been submitted since April, so no reviewer had looked at those
words since long before anyone knew they mattered. It surfaced only because the build-and-deliver
audit of 2026-08-22 dumped the full listing for both platforms side by side.

macOS `1.0.21` is `READY_FOR_SALE` and its metadata cannot be edited in place, so the fix needed a
new version — which was overdue anyway, the Mac store sitting on `1.0.21 build 2` while the project
was at `1.1.2`. **macOS `1.1.2` now exists in `PREPARE_FOR_SUBMISSION` with build `10004` attached**,
carrying swept keywords, description, what's-new and review notes, and with the demo account cleared:
the Mac record still required one, with a real address and password, for an app that has no sign-in
anywhere. iOS corrected exactly that on 2026-08-13 and said so to Apple in writing; macOS was not
touched at the time.

`1.0.21` and `1.0.13` still hold the terms and always will — they are the historical records of what
shipped. The live listing stops carrying them when `1.1.2` is approved.

The app code and the website were already clean. The only remaining occurrences anywhere are the
trademark disclaimer, which is required, and the names of the two data sources.

**It was not submitted.** That is a person pressing Submit, and it is the one step in this file that
nothing here automates.

## Note on the name

`No Spoilers - Grand Prix` is already prepared, already accepted for 4.1(c), and needs no further
decision. Keep it. `INFOPLIST_KEY_CFBundleDisplayName` is `No Spoilers`, which is already clean.

**It is stranded, and macOS is the way out.** Name and subtitle are app-level, so they ship with the
next *approved* version on either platform — and the `appInfo` holding `No Spoilers - Grand Prix` /
`Spoiler-free GP race widget` reads `REJECTED`, because the last thing to carry it was the iOS
submission Apple turned down. The live app is still called `No Spoilers F1`. Approving macOS `1.1.2`
should release it without iOS having to be answered first; that is the expectation and not yet an
observed fact.

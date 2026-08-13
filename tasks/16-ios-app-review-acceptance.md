# Task 16: Get the iOS app through App Review

**Status: OPEN. Two live rejection reasons, and the harder one is not about branding.**

iOS `1.0.21` has been `REJECTED` since 2026-04-27. Four review rounds, four rejections, and the
thread has sat unanswered in `UNRESOLVED_ISSUES` since 2026-05-17. macOS is unaffected and on sale.

The full Resolution Center thread was retrieved on 2026-08-13 from the private
`appstoreconnect.apple.com/iris/v1/resolutionCenterThreads/…/resolutionCenterMessages` endpoint,
using a browser session cookie. **There is no public API for this** — `appstore_status.py` reports
the state and says so. Anything below quoted from Apple is verbatim.

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

The pending rename lives in a second appInfo (`859a5495`, `REJECTED`) and cannot take effect while
the version is rejected. A reviewer examining "the metadata" for this app can see the macOS side.

### And the website

`docs/index.html` uses "F1" six times and "Formula 1" once; `docs/privacy.html` and `docs/brand.md`
also. Both `supportUrl` and `marketingUrl` point there.

---

## 4.2.2: the real blocker, and no amount of metadata editing touches it

Apple has cited this in three of four rejections and has never engaged with the argument against
it. The 05-01 reply was detailed and good — the spoiler-free premise, the results fields that do not
exist in the domain model, the WidgetKit extension, App Group caching, offline support, OpenF1
session end-times, no `WKWebView` anywhere. Apple's response was a boilerplate list of design
videos.

Arguing again is unlikely to work. **What has not been tried is making the native functionality
visible in the listing itself.**

The listing carries **one** iPhone screenshot and **one** iPad screenshot, both showing a scrolling
list of sessions. That is precisely what "content aggregated from the Internet, not sufficiently
different from a web browsing experience" looks like. The single strongest 4.2.2 counter-argument —
a Home Screen widget that renders the next session without opening anything — **is not shown at
all.**

Concrete moves, in order of value:

1. **Screenshot the widget on a Home Screen.** Small, medium and large families if they exist. This
   is the one thing that cannot be a web page.
2. **Fill the remaining screenshot slots** — up to 10 are allowed, 1 is used. Show the countdown,
   the tabbed schedule, offline state, the About screen.
3. **Consider native surfaces that make the point structurally**, not just visually: a Live Activity
   or Dynamic Island for a running session, local notifications ahead of a session start, Lock
   Screen widgets, a Shortcuts/App Intents action. Each is impossible in a browser. This is product
   work and needs a decision about scope.
4. **Put the widget in the App Review notes** with an explicit instruction to add it to the Home
   Screen, since a reviewer will not discover it otherwise.

`whatsNew` for iOS `en-GB` is also empty, which `appstore_status.py` flags.

---

## Plan

### Phase 1 — remove the logo (unblocks 4.1(a), and makes the correction honest)

- Replace the `f1logo` asset with an original mark. `nospoilers-icon.imageset` exists in the same
  catalogue and may serve.
- `NoSpoilersWordmark` in `SharedChrome.swift` is the shared boundary — change it there and all
  three call sites follow. Do not special-case the menu bar.
- **Fail fast**: the replacement must be a required resource. No `??`, no placeholder image, no
  sentinel. Missing asset must crash.
- Delete `f1logo.imageset` and the Wikimedia acknowledgement row in `AboutView.swift`.
- **Keep the trademark disclaimer** — it is accurate and appropriate for an app that schedules
  someone else's events.
- All user-visible strings via `Strings.swift`, including `Strings.About.branding` (currently
  `"F1 logo"`).

### Phase 2 — clean the remaining metadata

- Retake **all** screenshots after Phase 1, on both platforms. The current ones contain the logo.
- De-brand the macOS listing: name, subtitle, keywords, description.
- De-brand `docs/index.html`, `docs/privacy.html`, `docs/brand.md`, `README.md`.
- Write iOS `whatsNew`.

### Phase 3 — answer 4.2.2 with screenshots, not prose

Widget-on-Home-Screen screenshots first; decide on Live Activities / notifications / App Intents
separately.

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

- [ ] `grep -rn "f1logo" --include="*.swift" .` returns nothing
- [ ] `f1logo.imageset` deleted
- [ ] `verify-core-tests.sh`, `verify-ios-build.sh`, `verify-mac-build.sh`, `verify-widget-build.sh` pass
- [ ] No screenshot on either platform contains the Formula One wordmark
- [ ] At least one iOS screenshot shows the Home Screen widget
- [ ] macOS listing free of "F1" / "Formula 1" in name, subtitle, keywords, description
- [ ] Website and README de-branded
- [ ] iOS `whatsNew` written
- [ ] Resolution Center answered, including the correction
- [ ] `appstore_status.py` shows the iOS version out of `REJECTED`

---

## Decisions needed

1. **The logo — confirm removal everywhere.** Menu-bar-only was floated as a compromise; it does
   not survive contact with this thread, because the menu bar icon is the macOS app's identity and
   the same asset feeds the iOS wordmark that is already in evidence on the listing.
2. **How far to go on 4.2.2.** Screenshots alone may be enough, or it may need a Live Activity /
   notifications. Cheapest first: retake screenshots, resubmit, and see whether 4.2.2 survives.
3. **Whether to fix the macOS listing now.** It is on sale and uncomplained-about, but it shares the
   app record with the thing under review.

## Note on the name

`No Spoilers - Grand Prix` is already prepared, already accepted for 4.1(c), and needs no further
decision. Keep it. `INFOPLIST_KEY_CFBundleDisplayName` is `No Spoilers`, which is already clean.

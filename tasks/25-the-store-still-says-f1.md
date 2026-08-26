# Task 25: the store still says F1, and only an approval can change it

**Status: BLOCKED on iOS. Raised 2026-08-25, deliberately not started.**

## Why

The public App Store page reads:

- name — `No Spoilers F1`
- subtitle — `F1 race weekend schedule`

Read off `apps.apple.com/gb/app/id6761343835` on 2026-08-25, not inferred from the API. That is the
macOS app, live, under a name carrying the mark that `CLAUDE.md` makes a non-negotiable and that
three 4.1(a) Copycats rejections came off.

**It is already fixed everywhere a person would look.** `No Spoilers - Grand Prix` and
`Spoiler-free GP race widget` are entered in App Store Connect and show as *pending* against both
platforms' 1.1.2. The app record's own name is already the new one.

**They are pending because name and subtitle belong to a version, not to the app.** Typing them does
not publish them; an *approval* publishes them. The rename has been queued behind the iOS approval
since the wordmark sweep of 2026-08-13, and iOS has been rejected four times in that window. So the
mark has stayed live on the store for the whole of it.

## Why this is not being done now

**The macOS app is live and shipping it is a risk with no upside until iOS lands.** Nick's call,
2026-08-25, and it is the right one: a macOS submission puts an approved, selling product back in
front of App Review, on the same record that is currently in an unresolved 4.2.2 argument. A
Copycats reviewer looking at the record afresh is exactly what the last four months have been about
avoiding.

The exposure is real but it is old, static, and not what is blocking the product. **iOS first.**

## What to do, when iOS is live

Nothing, most likely — **the iOS approval carries the rename by itself.** The pending name and
subtitle are attached to both platforms' 1.1.2, so whichever version is approved first publishes
them. That is the whole fix, and it needs no separate release.

Check it rather than assume it: after the iOS version goes live, run `scripts/appstore_status.py`
and confirm the store line below has gone, then load the public page and read the name.

If for some reason iOS ships and the store still reads `No Spoilers F1`, the fallback is a macOS
1.1.2 submission — build 10006 is already attached to that version record and `listing/macos/*.txt`
is current. That is a real release and goes through `release-and-delivery`.

**Whenever the next macOS build is made, photograph the popover first.** It has carried a bundled
wordmark face since 2026-08-26 (task 24, `BrandTypeface`) that has never been seen on macOS: the
build is green and the Core tests register the font in a macOS process, but no one has looked at the
pixels. `mac_screenshots.py` quits whatever is in the menu bar and launches the app it is given, so
it was not worth doing while the shipped app was live — which stops being true the moment a macOS
release is on the table. If the face failed to load, the wordmark renders in the system font and
nothing anywhere reports it.

## The report will be red until then, on purpose

`scripts/appstore_status.py` reports it under NEEDS YOU, for both platforms:

```
! MAC_OS 1.1.2 en-GB: the store still shows f1 — the fix is staged and reaches the public page only when a version is approved
! IOS 1.1.2 en-GB: the store still shows f1 — the fix is staged and reaches the public page only when a version is approved
```

**Do not silence it.** That check used to merge each pending value over its live one, so the staged
rename hid the live name it was staged to replace and the report called the listing clean for
months. The masking was deliberate, with a comment and a selftest case both arguing it was "a line
that cannot be actioned and never goes away" — and the argument expired the moment the approval
carrying the fix started bouncing. Split back into two questions in `096b88f`, with the selftest case
inverted rather than deleted so nobody re-derives the old reasoning.

Two standing red lines is the correct state of the report while this is true. It goes green on the
approval, not on an edit.

## The hole underneath it

**Name and subtitle are the last listing copy that exists only in a web form.** `listing/` is the
source of truth for description, keywords, promotional text, what's-new and review notes;
`appstore_listing.py` writes those five and nothing else. Name and subtitle live on a different App
Store Connect page and no API this repository uses touches them.

That is precisely the condition `listing/README.md` was written to end — copy nothing can review,
diff, or check — and this task is what it looks like when it bites a second time. Recorded in that
README on 2026-08-25. Bringing them in means `appAppInfoLocalizations` rather than
`appStoreVersionLocalizations`, which is a different endpoint and a different edit page, and it is
not urgent while the report watches them.

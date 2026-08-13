# Task 18: Automate App Store screenshots — seed, then capture

**Status: DONE for iPhone, 2026-08-13. `tmp/screenshots/iphone-11-pro-max.png` is a clean
1242 × 2688 capture of the widget with live countdowns and nothing else on the page.** The one
manual step — placing the widget on Home Screen page 1 of
`BA115C57-DAB3-4EAF-9590-222F33DC5567` — is done and is device state, so every future run is fully
scripted. iPad is not done; nobody has decided whether the listing needs one.

**It paid for itself on the first good capture.** The label under the widget read `NoSpoilersApp`:
the iOS target had no `INFOPLIST_KEY_CFBundleDisplayName`, so the Home Screen name fell back to
`PRODUCT_NAME` → `TARGET_NAME`, while `NoSpoilersMac` had set it to `"No Spoilers"` all along. The
app has never shipped on iOS so no user saw it, but it would have gone out with the next approval.
**No screenshot of the app's own UI could have caught this** — only the widget puts the containing
app's name on screen. Fixed in `7d64a1b`.

**The wordmark does not block this screenshot.** `NoSpoilersWordmark` / `f1logo` appear in
`NoSpoilers/NoSpoilers/ContentView.swift:138,241` and the macOS app, but **not anywhere in
`NoSpoilersWidget.swift`**. So this capture is already free of the Formula One mark and does not
have to wait for task 16 Phase 1 — unlike any screenshot of the app's own UI, which does.

`scripts/screenshots.py`. Whole run takes 22 seconds:

```
scripts/screenshots.py --device BA115C57-DAB3-4EAF-9590-222F33DC5567 --expect 1242x2688
  seeded    .../AppGroup/32C9C09C-.../schedule-cache.json
  captured  tmp/screenshots/iphone-11-pro-max.png
  1242x2688 — accepted
```

**Scope, decided 2026-08-13: one screenshot. It is a widget — it does not need ten.**

Serves task 16: the iOS listing carries one iPhone and one iPad screenshot, both of a scrolling
list, and **the widget is not pictured at all** — which is the single strongest answer to the
standing 4.2.2 rejection. Task 17 records the decision this rests on: on iOS the core product *is*
the live updating widget, so a listing that does not show it is not showing the product.

Screenshots have to be retaken anyway once the Formula One wordmark comes out (task 16 Phase 1),
so this is the moment to stop doing it by hand.

---

## What was verified, 2026-08-13

Everything below was run, not assumed.

- **Capture works and is exact.** `xcrun simctl io booted screenshot out.png` wrote a
  1206 × 2622 PNG from the booted iPhone 17 — true device resolution, which is what App Store
  Connect requires.
- **The required devices are already installed.** `iPhone 17 Pro Max` and `iPad Pro 13-inch (M5)`
  both appear in `xcrun simctl list devices available`.
- **The App Group container is reachable from the host.**
  `xcrun simctl get_app_container <device> <bundle> <group id>` is a documented container mode
  (`app` | `data` | `groups` | a specific group id).
- **The data path is a single file.** `ScheduleCache` writes `schedule-cache.json` into the App
  Group container, as `{ cachedAt, weekends }` with `.iso8601` dates
  (`NoSpoilersCore/Sources/NoSpoilersCore/ScheduleCache.swift:13-45`).
- **Identifiers:**
  ```
  app     pomocorp.NoSpoilers.NoSpoilersMac
  widget  pomocorp.NoSpoilers.NoSpoilersMac.NoSpoilersWidget
  group   group.pomocorp.no-spoilers
  kind    "NoSpoilersWidget"   families: systemSmall, systemMedium, systemLarge
  ```
- **Screenshot sets are per family**, `APP_IPHONE` and `APP_IPAD` on iOS
  (`scripts/appstore_status.py:100-103`), which is what any later upload step must target.

**Not verified, and to be checked before relying on it:** that a widget placed on a simulator Home
Screen survives shutdown and reboot. It is device state so it should, but the whole design leans on
it.

### Three things that only came out of running it

1. **The required size is not the newest phone.** App Store Connect's iPhone slot on this listing
   asks for **1242 × 2688 or 1284 × 2778** — the 6.5"/6.7" sizes. `iPhone 17 Pro Max` captures
   1320 × 2868 and would be refused. **`iPhone 11 Pro Max` is natively 1242 × 2688** and is already
   installed. `--expect 1242x2688` makes a wrong device fail in seconds instead of at upload;
   resizing is not an option, the aspect ratios differ.

2. **`CODE_SIGNING_ALLOWED=NO` strips the App Group entitlement, and the seed step then has nowhere
   to write.** `scripts/verify-ios-build.sh` uses that flag, correctly — it only needs a compile.
   A screenshot build must not copy it: without the entitlement
   `simctl get_app_container … group.pomocorp.no-spoilers` exits 117 and there is no shared
   container at all. Build with default simulator signing:
   ```
   xcodebuild build -project NoSpoilers/NoSpoilers.xcodeproj -scheme NoSpoilersApp \
     -destination 'id=<udid>' -derivedDataPath tmp/DerivedData/NoSpoilersApp-sim \
     COMPILER_INDEX_STORE_ENABLE=NO
   ```
   `codesign -d --entitlements` reports an empty dict for a simulator build either way, so it is a
   misleading check. Ask `simctl get_app_container … groups` instead — that answers the question
   that matters.

3. **Device names are not unique, even within one runtime.** This machine has two `iPhone 11 Pro
   Max`, both on iOS 26.4. The script refuses to guess and prints the UDIDs; pass one. Same for
   `-destination`, which fails the build with a device list if the name is ambiguous.

4. **The Today View is not the Home Screen, and the widget has to be on the Home Screen.** Adding a
   widget by swiping right lands it on the Today View, which the capture can never reach: a boot
   always returns to Home Screen page 1, and `simctl` has no gesture, scroll or page-navigation
   verb. This caught two attempts in a row on 2026-08-13 and both times the evidence looked like a
   missing or broken widget rather than a wrong page.

   **Telling them apart in a screenshot: the Today View has no dock and no Search pill.** If the
   image has a dock, it is a Home Screen page. Move the widget with long-press → Edit Home Screen →
   drag right onto page 1, and clear the stock Maps and Calendar widgets off that page while in
   jiggle mode or they end up in the App Store listing.

5. **The other simulator on this machine runs a different app.** `iPhone 17` has a build from before
   the bundle-ID change installed — `get_app_container … pomocorp.NoSpoilers.NoSpoilersMac` returns
   *No such file or directory* there, and its widget logs under
   `pomocorp.NoSpoilers.NoSpoilersWidget` rather than
   `pomocorp.NoSpoilers.NoSpoilersMac.NoSpoilersWidget`. It is not a target device — it captures
   1206 × 2622, which this listing does not accept — so delete the stale app rather than debug it.

### The hazard, demonstrated

The first real run captured a valid 1242 × 2688 Home Screen with no NoSpoilers widget on it and no
error of any kind — which is exactly the failure this task predicted. Until the widget is placed,
every run produces a correct picture of the wrong thing.

It then did it three more times, across two separate rounds of "it's added now", because the widget
was on the Today View. Each capture was a correct screenshot of Home Screen page 1, and page 1
genuinely had no NoSpoilers widget on it. **The script cannot distinguish "you have not added it"
from "you added it somewhere I cannot photograph", and the output looks identical.** That is the
argument for the baseline check under Verification below, not a nice-to-have.

### Do not launch the app between seeding and capture

Demonstrated 2026-08-13: opening the app to find the widget replaced the 3-weekend fixture with the
real 23-weekend calendar within seconds, exactly as `ScheduleStore.refresh()` predicts. Harmless —
re-running the script re-seeds — but a capture taken in that window shows live data and is not
reproducible.

---

## The shape

Three steps, and only the middle one is interesting.

### 1. Seed — make the screenshot say the same thing every time

Write a fixture `schedule-cache.json` into the App Group container before capturing. Without this,
the screenshots depend on whether a race happens to be upcoming, and out of season the widget
renders its off-season state — a correct screenshot of nothing.

**Fixture dates must be offsets from now, computed at seed time, never absolutes.** The widget
renders `Text(date, style: .relative)` throughout (`NoSpoilersWidget.swift:370, 378, 469, 598, 615,
690, 698`), which the system evaluates live against the wall clock. An absolute fixture produces a
screenshot reading "3 months ago" a quarter later, and it will do it silently.

Pick offsets that show the app at its best and exercise more than one state: a session finished, a
session live, a session upcoming.

**Do not launch the app after seeding — it destroys the fixture.** `ScheduleStore.refresh()`
fetches from the network and then calls `cache.save(...)` *unconditionally*
(`NoSpoilersCore/Sources/NoSpoilersCore/ScheduleStore.swift:83-86`). It does not consult
`isFresh`, so a fresh fixture is no defence: the first refresh overwrites it with the real
calendar, and the screenshot then shows whatever the season actually holds.

**Rebooting the simulator is the forcing function instead.** The widget reads the cache directly
(`resolveWidgetData()` returns on a non-empty cache hit and never touches the network), and a boot
makes WidgetKit request fresh timelines for everything on the Home Screen. So the order is: write
fixture → `simctl shutdown` → `simctl boot` → wait → capture, with the app never launched.

The fixture is `[RaceWeekend]`, which encodes as
`{round, name, location, sessions: {<kind>: <iso8601>}}`. Kind keys are the feed's, not Swift's:
`fp1`, `fp2`, `fp3`, `qualifying`, `sprintQualifying`, `sprint`, `gp`
(`SessionKind.swift:4-10`). `name` must be one of the values `RaceWeekend.countryCode` switches on
or the flag falls back to 🏁 (`RaceWeekend.swift:22-45`).

### 2. Place the widget — the one step that cannot be scripted

There is **no `simctl` command to add a widget to the Home Screen.** XCUITest can drive SpringBoard
through long-press → jiggle → `+` → search → Add, but it is fragile across iOS versions and is not
worth building on for something done rarely.

Do it by hand, once per simulator. It is device state, so it persists, and every run afterwards is
fully scripted.

**The hazard this creates must be designed for.** If the widget is absent, the script captures a
perfectly valid screenshot of a Home Screen without it — a success that looks exactly like success.
This is the same failure shape as the *What to Test* note in `docs/guides/building.md`: the test is
not "did we get a screenshot" but "does this screenshot contain the thing it exists to show".
Options, cheapest first: fail if the PNG is byte-identical to a captured no-widget baseline; require
`--confirm-widget-placed`; or open the output for a human at the end. **A missing widget must be
loud, not a fallback.**

### 3. Capture

`xcrun simctl io <udid> screenshot`, per device, into a versioned output directory.

Uploading to App Store Connect (`appScreenshotSets` / `appScreenshots`) is a **write**, so it needs
the App Manager key `ASC6H3SL2D` rather than the read-only `S394C74APG` — see
`docs/guides/building.md` on why those two are kept apart. Out of scope for a first version; the
files can be dragged in.

---

## Fail-fast requirements

Per `CLAUDE.md`, and because every one of these has a tempting silent fallback:

- Simulator not found, not bootable, app not installed → crash with the device name and what to run.
- App Group container path missing → crash. Never fall back to the app's own data container: the
  widget reads the group, so a screenshot taken against the wrong container shows stale data and
  looks fine.
- Fixture fails to encode, or `ScheduleCache` cannot read it back → crash.
- No `?? default`, no placeholder image, no "captured 1 of 2 devices, continuing".

---

## Decided: Python, `scripts/screenshots.py`

The repo has two conventions and this sat between them: `scripts/*.sh` for build and release
orchestration, stdlib-only Python for anything talking to App Store Connect. Python won because the
fixture needs JSON with dates computed relative to now, which is unpleasant in bash, and because an
upload step would belong beside the other App Store Connect writers and could reuse their token
signing. **Not a third convention.**

One deliberate departure from `testflight_distribute.py`: **`--dry-run` exists but is not the
default.** That script defaults to dry-run because it writes to App Store Connect, where a mistake
is public. This one writes to a simulator and a local directory, and rebooting a simulator you own
is not a thing to be protected from.

---

## Verification

- [ ] Two consecutive runs with no code change produce identical screenshots
      *(they will not, and cannot: the countdowns advance between runs — "3 hrs, 59 min" became
      "3 hrs, 54 min" five minutes later. Reframe this as "differ only in the countdowns and the
      status-bar clock" before trying to satisfy it.)*
- [ ] A run with the widget removed from the Home Screen **fails**, and says why
      — **still the biggest gap.** Four runs produced valid screenshots with no widget in them and
      exit code 0. Now that a good capture exists it can serve as the baseline for this check.
- [ ] A run months later still shows a sensible countdown, not "3 months ago"
- [x] Output resolutions match what App Store Connect accepts for each family — 1242 × 2688,
      enforced by `--expect`
- [x] Every captured screenshot is free of the Formula One wordmark — the widget never used it, so
      this one does not depend on task 16 Phase 1
- [x] `scripts/verify-*.sh` unaffected — `verify-ios-build.sh` passes; the only app-code change was
      the display-name setting, which was a bug this task found
- [ ] `docs/guides/building.md` and `docs/guides/important-code.md` updated with the new script
- [ ] Decide whether the iPad slot needs a screenshot too, and if so which simulator produces an
      accepted size

---

## Related

- **Task 16 Phase 2/3** consumes the output; do task 16 Phase 1 (remove the logo) first or every
  screenshot is thrown away.
- **Task 17** records that the App Store is the core product on both platforms, and the widget on
  iOS.
- Noted while reading the widget: `NoSpoilersWidgetBundle` registers **only** `NoSpoilersWidget()`.
  `NoSpoilersWidgetLiveActivity.swift` and `NoSpoilersWidgetControl.swift` are in the target but not
  in the bundle, and both are unmodified Xcode template stubs — the Live Activity renders
  `Text("Hello \(context.state.emoji)")`. Task 16 floats Live Activities as a possible 4.2.2 answer;
  that scaffolding is boilerplate, not a head start. Separate decision, separate task.

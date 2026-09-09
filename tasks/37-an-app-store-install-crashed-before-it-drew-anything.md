# An App Store install crashed before it drew anything

**Status: OPEN, 2026-09-09.** The launch path no longer traps and reports itself on screen instead.
The cause is not confirmed — that needs the reporter's crash log, which nobody has asked for yet.

## The issue

Someone installed 1.1.3 from the App Store on an iPhone and it crashed instantly, every time. It
works on the owner's phone and on other people's. No crash log has been collected, so the cause is
inferred from the code rather than observed.

## What the launch path actually does

Read on 2026-09-09. Everything up to the first frame, in order:

1. `NoSpoilersApp.init` — `AppLog.launched`, which reads `AppVersion.build`. **Traps** on a bundle
   with no `CFBundleVersion`, and that is the same bundle on every device, so it cannot explain one
   phone.
2. `ScheduleStore.init` — the App Group cache load is inside a `do/catch` that treats a missing file
   as ordinary (`ScheduleStore.swift:31`), and `SessionEndConfirmer` falls back to `.standard` when
   `UserDefaults(suiteName:)` returns nil. Nothing here can trap.
3. `ContentView.body` — opens with `NoSpoilersWordmark(size: .large)`, which calls
   `BrandTypeface.wordmark`, which forces `registerOnce`. **Three `preconditionFailure`s**, live in
   release builds, before a single pixel.

Step 3 is the only device-dependent trap on the path, which makes it the candidate.

## The likeliest cause, unconfirmed

`CTFontManagerRegisterFontsForURL(url, .process, &error)` returns `false` when a face of that name
is already registered on the device. Font-installer apps and configuration profiles install faces
system-wide, so a phone that already carries Chivo refuses the bundled copy and the old line 82
trapped. The resolution check on the old line 92 fails the same way if a different Chivo is present.

Ruled out: the bundle branch. `NoSpoilersCore_NoSpoilersCore.bundle` is embedded in the built
`.app` — visible in the `ProcessInfoPlistFile` step of `verify-ios-build.sh`.

Not ruled out: anything else on that phone. This is a reading of the code, not a diagnosis of a
device.

## What was done

The three traps were the bug regardless of which one fired. A `preconditionFailure` in a shipped
build is a silent disappearance: the user learns nothing, we learn nothing, and the app does not
run. The same fault reported on screen leaves them a working app and us a sentence.

- [x] `BrandTypeface` keeps the traps under `#if DEBUG` and routes the identical message to
      `LaunchDiagnostics` in release, falling back to `.system(size:weight: .heavy)` — the face
      `docs/guides/brand.md` measured Chivo against. The fallback is never silent, which was the
      whole objection to having one.
- [x] `LaunchDiagnostics` records faults once per id, logs them to `AppLog.launch`, and carries a
      launch-stage breadcrumb: every launch writes `starting`, only one that reaches the screen
      writes `shown`, so finding `starting` on the way in means the run before died before drawing.
- [x] `LaunchProblemBanner` draws nothing on an ordinary run and otherwise shows one line per fault
      above the pager, opening a sheet with the full text, `.textSelection` and a `ShareLink`.
- [x] `verify-core-tests.sh` — 125 tests, 0 failures (118 before).
- [x] `verify-ios-build.sh`, `verify-widget-build.sh`, `verify-mac-build.sh` — all BUILD SUCCEEDED.

## What is left

- [ ] **Ask the reporter for the crash log.** Settings → Privacy & Security → Analytics &
      Improvements → Analytics Data → `NoSpoilers-2026-…​.ips` → Share. It names the exact function
      and settles which of the three checks fired, which none of the above does. Xcode's Organizer
      shows the same thing if they have analytics sharing on. **This is the only step that turns
      the guess into a fact, and it does not need a new build.**
- [ ] **Ship it**, since a fix nobody can install fixes nothing. 1.1.4 is not yet submitted.
- [ ] **Unverified on a device.** The banner has never been seen on a phone: the fault cannot be
      provoked on demand, and the tests cover the recorder rather than the failure that feeds it.
- [ ] **The breadcrumb cannot report a fault that kills every launch** — the report needs a launch
      that survives to show it. It is the net under the next unknown fault, not under this one.
      That is why the known traps were removed rather than merely instrumented.
- [ ] **macOS is not wired up.** `LaunchProblemBanner` is in Core and compiles for both, but only
      `NoSpoilers/ContentView.swift` draws it and only the iOS entry point calls `beginLaunch`. The
      menu-bar popover is a different shape and the crash was not reported there.
- [ ] **`AppVersion` still traps** on a bundle with no version keys, deliberately and unchanged. It
      is a misbuilt bundle rather than a runtime condition, it is identical on every device, and the
      fallbacks it replaced caused a permanent "update available" banner on macOS.

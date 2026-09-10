# An App Store install crashed before it drew anything

**Status: OPEN, 2026-09-10.** The cause is confirmed from the reporter's crash logs: 1.1.3 imports a
system symbol iOS 26.2.1 does not have, and dyld refuses to launch it. The call is removed and the
iOS minimum is now 26.4. Neither is shipped.

## The issue

Someone installed 1.1.3 from the App Store on an iPhone and it crashed instantly, every time. It
works on the owner's phone and on other people's.

## The cause, confirmed 2026-09-10

Three crash logs, `NoSpoilersApp-2026-09-08-215447.ips`, `-215646.ips` and `-215646.000.ips`, all
the same: 1.1.3 (112) from the App Store, `iPhone18,1`, iOS 26.2.1 (23C71), `EXC_CRASH`/`SIGABRT`,
termination namespace `DYLD`, "Symbol missing":

    Symbol not found: _$s2os6LoggerV9isEnabled4typeSbSo0a5_log_E2_ta_tF
    Expected in:     /usr/lib/swift/libswiftos.dylib

That is `Logger.isEnabled(type:)`, called once, by `LogChannel.debug`, since `41a5a3b`
(2026-08-17). `ios/v1.1.3`, `macos/v1.1.3` and `v1.1.4` all contain it.

- The Xcode 26.6 SDK (`iPhoneOS26.5.sdk`) declares it `iOS 14.0`, and its `libswiftos.tbd` lists the
  symbol with no version, so neither the compiler nor the linker had anything to object to.
- The iOS 26.3.1 simulator runtime does not export it; 26.4, 26.4.1 and 26.5 do. It arrived in
  iOS 26.4. The deployment target was 26.2, so a phone on 26.2 or 26.3 died at launch and a newer
  one did not, which is the "works on other phones" in the report.
- dyld stops the process before `main`, so none of the launch-path traps below was reached. The
  font-registration hypothesis this file carried on 2026-09-09 was wrong about this crash.

## Keeping it from recurring: decided 2026-09-10

**The iOS deployment target is 26.4, and the App Store enforces it.** A phone below it cannot
install the version. Nothing inside the app could say "update iOS" instead: dyld kills the process
before any of our code runs.

This does not stop the next one. The SDK is always newer than the minimum, so another mislabelled
API will pass the build the same way and surface as crash reports.

Rejected:

- **A build-time import check (`scripts/min_os_symbols.py`), on the owner's call as too much for
  the failure's rarity.** It was built and worked, and was never committed. For each Mach-O in the
  built `.app`, `dyld_info -imports` minus `[weak-import]`, checked against `dyld_info -exports` of
  the same library inside the simulator runtime whose `ProductVersion` equals `MinimumOSVersion`,
  following re-exports; a runtime's `libsystem_sim_{kernel,platform,pthread}_host.dylib` re-export
  the Mac's libraries, so those three were answered from the host. On the 2026-09-09 build it
  flagged exactly `Logger.isEnabled(type:)`, in the app's and widget's `.debug.dylib`, against
  26.3.1's export lists, and nothing across 2307 imports against 26.4. The cost that sank it: the
  exact minimum-iOS runtime, about 8.4 GB, on every agent and laptop, again after every
  deployment-target change. It is the only approach here that catches the next one before a user.
- A launch test on a minimum-iOS simulator. Boots simulators on the agent whose `posix_spawn` wedge
  traces to leaked simulator processes, and a launch never loads the widget.
- A compiler or linker flag. None helps: the SDK is the input both trust.

## What was done

- [x] **The call is gone.** `LogChannel.debug` no longer guards with `isEnabled`. `Logger` only
      evaluates an interpolation for an enabled level, so the JSON is still built only when
      something is reading. Its comment says why not to bring the guard back, including that the
      Mac target's minimum is still 26.2.
  - `scripts/verify-core-tests.sh` — 125 tests, 0 failures, 2026-09-10.
  - `swift build --triple arm64-apple-ios26.2` of `NoSpoilersCore` compiled, and `nm -u` finds no
    `LoggerV9isEnabled` in `LogChannel.swift.o` for iOS or macOS while still finding the other
    `Logger` symbols.
- [x] **`IPHONEOS_DEPLOYMENT_TARGET` is 26.4** in the project's Debug and Release configurations.
      Read back from `project.pbxproj` through `plutil`: no target sets its own, so the app and the
      widget inherit it. `MACOSX_DEPLOYMENT_TARGET` stays 26.2. `README.md` says so.
- [ ] **`verify-ios-build.sh`, `verify-mac-build.sh` and `verify-widget-build.sh` could not run
      2026-09-10**: the agent sandbox's `sandbox_apply: Operation not permitted`, as in task 30.
      Run them from a normal shell, and confirm the built app's and widget's `MinimumOSVersion`
      read 26.4.
- [x] **The launch-path traps, 2026-09-09.** `BrandTypeface` keeps its three `preconditionFailure`s
      under `#if DEBUG` and in release reports the fault to `LaunchDiagnostics` and falls back to
      `.system(size:weight: .heavy)`. `LaunchDiagnostics` keeps a `starting`/`shown` breadcrumb,
      and `LaunchProblemBanner` shows recorded faults above the pager. Core tests 125/0 and all
      three Xcode builds succeeded that day. It stands on its own, since a trap in a shipped build
      is a silent disappearance, but it does not touch this crash.

Not doing, decided 2026-09-10: a fixed build at the 26.2 minimum before the one at 26.4. The App
Store offers a phone below the minimum the last version that supported it, which makes the call,
so 26.2 and 26.3 phones keep a crashing build. Only a couple of people have installed the app.

## What is left

- [ ] **Ship it.** 1.1.3 and 1.1.4 both carry the call, so the fix needs a new build on both
      platforms.
- [ ] **macOS is fixed by the same removal but unverified.** Same `LogChannel`, minimum 26.2, no Mac
      crash reported, and nothing checked what macOS 26.2 exports.
- [ ] **Unverified on a device**: the banner has never been seen on a phone.
- [ ] **macOS launch reporting is not wired up.** Only `NoSpoilers/ContentView.swift` draws
      `LaunchProblemBanner`, and only the iOS entry point calls `beginLaunch`.
- [ ] **`AppVersion` still traps** on a bundle with no version keys, deliberately: a misbuilt bundle
      is identical on every device, and the fallbacks it replaced caused a permanent "update
      available" banner on macOS.

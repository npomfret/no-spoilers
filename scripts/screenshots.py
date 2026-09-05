#!/usr/bin/env python3
"""Capture App Store screenshots from a simulator, against fixture data.

The point of this script is that the same command produces the same picture in
March and in August. Screenshots taken against the live calendar do not: out of
season the widget correctly renders its off-season state, and mid-season it
renders whatever race happens to be next.

What it does, per device:

    write fixture -> shutdown -> boot -> settle -> screenshot

Two of those steps look redundant and are not.

**One bootstrap launch is required on a newly created simulator.** WidgetKit has not registered the
extension until its containing app has launched once; without it, SpringBoard drops the widget and
the script's supported-family error points at the wrong cause. Launch the app once, let it settle,
terminate it, then run this script. The script seeds the fixture after that launch.

**The app is never launched during capture.** `ScheduleStore.refresh()` fetches from the network
and then calls `cache.save(...)` unconditionally — it does not consult
`isFresh` — so the first refresh replaces the fixture with the real calendar.
Launching the app to "make it pick up the data" destroys the data.

**Capturing the app itself is a manual three-command procedure, on purpose.**
It exists and it works — install a signed simulator build, launch it, wait
about eight seconds, `simctl io screenshot` — and two consecutive captures
differ only in the status-bar clock and the two countdowns that tick. But it
races the fetch. A fetch that *fails* leaves the fixture intact, because the
`catch` in `performRefresh` writes nothing and keeps the published state; a
fetch that succeeds replaces both the cache and the screen. Out of season that
race is usually won, which is exactly what makes it untrustworthy as a mode.

    xcrun simctl install <udid> <NoSpoilersApp.app>   # signed, not CODE_SIGNING_ALLOWED=NO
    xcrun simctl launch  <udid> <app bundle id>
    xcrun simctl io      <udid> screenshot out.png    # after ~8s

**There is deliberately no `--app` flag over it.** Making it reliable means
suppressing the fetch, and nothing outside the app can do that — it would take
a launch-argument branch inside `ScheduleStore`, and product code currently
reads no launch arguments anywhere. That trade was weighed on 2026-08-18 and
declined: the listing screenshots are widget screenshots, the manual path
covers the before/after diffing this is otherwise wanted for, and a flag whose
job is "do not refresh" is a bad thing to have one typo away from shipping.
Revisit it if app screenshots ever go on the listing, and read the seam as a
product capability — an offline mode — rather than as test scaffolding.

**The reboot renders; it does not reload.** Booting makes the Home Screen draw
every widget on it, and the widget reads the App Group cache directly rather
than the network, so on a device seeing this widget for the first time a seeded
fixture is what it draws. But WidgetKit keeps the generated timeline in
`Library/chronod/chrono.sql` and reuses it until its own reload date, which for
this widget is the next session boundary — hours away. **A reboot does not
invalidate it, and neither does restarting `chronod` or deleting `chrono.sql`
and the snapshot cache; all three were tried on 2026-08-13.** The screenshot
then shows a countdown computed hours ago, on a picture that is otherwise
perfect and internally consistent.

**`--install` is the invalidation.** Reinstalling the app drops the widget's
stored timeline, so the next boot regenerates it from the seeded cache. The run
that does the installing is not the usable one — see below — so the reliable
sequence for a device that has been captured before is `--install` once, then
capture again.

**Placing the widget is `--widget-size`, not a manual step.** There is no
`simctl` verb for it, but SpringBoard keeps the Home Screen layout in a plain
plist and reads it back on boot, so the widget and its size are just data:

    <device>/data/Library/SpringBoard/IconState.plist
      iconLists[0][0]  { bundleIdentifier, elementType: widget, gridSize: large }

`--widget-size` finds that entry and rewrites `gridSize`, or writes one from
scratch if the device has never had the widget placed. It must happen while the
device is shut down — SpringBoard rewrites the file on exit and would undo it.

Stdlib only, like the other Python here. No venv, no install.

Pick the device by the pixel size the listing's slot wants, not by what is
newest. As of 2026-08-13 the iPhone slot on this listing accepts 1242x2688 or
1284x2778 — the 6.5"/6.7" sizes — so `iPhone 11 Pro Max` (natively 1242x2688) is
the device, and `iPhone 17 Pro Max` at 1320x2868 is refused. Pass `--expect` and
find out in seconds rather than at upload.

**A fresh simulator without the bootstrap launch drops the widget.** Do not respond by changing
`supportedFamilies`; launch the app once, terminate it, and rerun the capture. Installing can also
leave the device on whichever page the new icon landed on rather than page 1, which looks exactly
like a missing widget.

Usage:
    scripts/screenshots.py --device "NoSpoilers-iPhone-65" --expect 1242x2688
    scripts/screenshots.py --device "NoSpoilers-iPhone" --device "NoSpoilers-iPad"
    scripts/screenshots.py --device "NoSpoilers-iPhone" --widget-size small
    scripts/screenshots.py --device "NoSpoilers-iPad" --widget-size extraLarge
    scripts/screenshots.py --device "NoSpoilers-iPhone" --install path/to/NoSpoilersApp.app
    scripts/screenshots.py --device "NoSpoilers-iPhone" --dry-run

`--dry-run` is not the default, unlike testflight_distribute.py. That script
defaults to dry-run because it writes to App Store Connect, where a mistake is
public. This one writes to a simulator and a local directory, and rebooting a
simulator you own is not a thing to be protected from.
"""

import argparse
import json
import plistlib
import subprocess
import sys
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

APP_BUNDLE_ID = "pomocorp.NoSpoilers.NoSpoilersMac"
APP_GROUP_ID = "group.pomocorp.no-spoilers"
WIDGET_BUNDLE_ID = f"{APP_BUNDLE_ID}.NoSpoilersWidget"
# The `kind` string NoSpoilersWidgetBundle registers, not a bundle identifier.
WIDGET_KIND = "NoSpoilersWidget"
CACHE_FILENAME = "schedule-cache.json"

# `gridSize` values SpringBoard accepts, and the families the widget declares in
# NoSpoilersWidget.swift. Keep the two in step: asking for a family the widget
# does not support gets the entry silently dropped from the layout.
#
# `extraLarge` is iPad-only — there is no iPhone Home Screen slot that shape, and
# SpringBoard drops the entry on one. Capture it on `NoSpoilers-iPad`, which is
# why that simulator exists. The spelling is camel-case where the others are
# lower-case; that is SpringBoard's, confirmed by writing it and reading back
# what survived the boot, not a guess.
WIDGET_SIZES = ("small", "medium", "large", "extraLarge")

# Relative to the device's `dataPath`, which simctl reports — the containing
# directory is derivable from the UDID but asking is what makes this survive a
# machine that keeps its simulators somewhere else.
SPRINGBOARD_STATE = "Library/SpringBoard/IconState.plist"

# How long to let the Home Screen settle after boot before capturing. WidgetKit
# renders a placeholder first and swaps in the real timeline a moment later; a
# screenshot taken too early catches the placeholder, which looks like a
# rendering bug rather than a timing one.
SETTLE_SECONDS = 12

# The fixture, as offsets from the moment the script runs.
#
# These MUST stay relative. The widget renders `Text(date, style: .relative)`
# throughout and the system evaluates it against the wall clock at display time,
# so an absolute fixture produces a screenshot reading "3 months ago" a quarter
# after it was written — silently, because the file is still perfectly valid.
#
# Chosen to show three states at once: sessions already run, and a race close
# enough that the countdown is the interesting part of the picture.
FIXTURE = [
    {
        "round": 14,
        "name": "Belgian",
        "location": "Spa-Francorchamps",
        "sessions": {
            "fp1": timedelta(days=-2, hours=-4),
            "fp2": timedelta(days=-2),
            "fp3": timedelta(days=-1, hours=-3),
            "qualifying": timedelta(days=-1),
            "gp": timedelta(hours=4),
        },
    },
    {
        "round": 15,
        "name": "Italian",
        "location": "Monza",
        "sessions": {
            "fp1": timedelta(days=13),
            "fp2": timedelta(days=13, hours=4),
            "fp3": timedelta(days=14),
            "qualifying": timedelta(days=14, hours=3),
            "gp": timedelta(days=15),
        },
    },
    {
        "round": 16,
        "name": "Singapore",
        "location": "Marina Bay",
        "sessions": {
            "fp1": timedelta(days=27),
            "fp2": timedelta(days=27, hours=4),
            "fp3": timedelta(days=28),
            "qualifying": timedelta(days=28, hours=3),
            "gp": timedelta(days=29),
        },
    },
]


def png_size(path: Path) -> tuple[int, int]:
    """Width and height from the PNG header.

    The IHDR chunk is fixed-position: 8-byte signature, 4-byte length, 4-byte
    type, then width and height as big-endian uint32. No decoder needed, which
    keeps this stdlib-only like the rest of the Python here.
    """
    header = path.read_bytes()[:24]
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"not a PNG: {path}")
    return (
        int.from_bytes(header[16:20], "big"),
        int.from_bytes(header[20:24], "big"),
    )


def check_size(path: Path, expected: list[tuple[int, int]]) -> None:
    """Refuse a screenshot App Store Connect would refuse.

    App Store Connect accepts exact pixel dimensions per slot and nothing else,
    and it tells you so only at upload — after the capture, the review of the
    image, and the walk to the browser. Failing here costs seconds instead.

    With no --expect the size is reported and explicitly not checked. That is
    not a default that quietly passes: the dimensions App Store Connect wants
    depend on which slot the listing uses and are not knowable from here.
    """
    actual = png_size(path)
    if not expected:
        print(f"  {actual[0]}x{actual[1]} — not checked, no --expect given")
        return
    if actual not in expected:
        allowed = ", ".join(f"{w}x{h}" for w, h in expected)
        raise SystemExit(
            f"{path} is {actual[0]}x{actual[1]}; App Store Connect wants one of: {allowed}\n"
            "Capture on a device whose native resolution is one of those — resizing to fit\n"
            "changes the aspect ratio and distorts the image."
        )
    print(f"  {actual[0]}x{actual[1]} — accepted")


def run(*args: str, check: bool = True) -> str:
    """simctl, with its stderr promoted to the exception message.

    simctl reports failure in stderr and an exit code, and its stdout is empty
    on error — so a caller that only reads stdout sees a successful-looking
    empty string.
    """
    result = subprocess.run(args, capture_output=True, text=True)
    if check and result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise SystemExit(f"{' '.join(args)} -> exit {result.returncode}\n{detail}")
    return result.stdout


def device_udid(name: str) -> str:
    """Resolve a device name — or a UDID, passed straight through — to one UDID.

    Duplicates are a hard stop rather than a pick-the-first. Every installed iOS
    runtime gets its own device of each type, all with identical names: this
    machine has two `iPhone 17 Pro Max`, one on iOS 26.4 and one on 26.5.
    Screenshotting the wrong OS version is exactly the wrong-but-plausible
    output this script exists to prevent, so the ambiguity is reported with the
    runtime that distinguishes them and the UDID to pass instead.
    """
    listing = json.loads(run("xcrun", "simctl", "list", "devices", "available", "-j"))
    by_runtime = [
        (runtime.split(".")[-1], device)
        for runtime, devices in listing["devices"].items()
        for device in devices
    ]

    for runtime, device in by_runtime:
        if device["udid"] == name:
            return device["udid"]

    matches = [(runtime, device) for runtime, device in by_runtime if device["name"] == name]
    if not matches:
        raise SystemExit(
            f"no available simulator named {name!r}\n"
            "  xcrun simctl list devices available"
        )
    if len(matches) > 1:
        # Sort on the key explicitly: two devices can share a runtime, and the
        # tuple comparison would then fall through to comparing dicts.
        found = "\n".join(
            f"  {device['udid']}  {runtime}"
            for runtime, device in sorted(matches, key=lambda m: (m[0], m[1]["udid"]))
        )
        raise SystemExit(
            f"{len(matches)} available simulators named {name!r} — pass one of these UDIDs "
            f"to --device instead:\n{found}"
        )
    return matches[0][1]["udid"]


def device_name(udid: str) -> str:
    """This device's name, for labelling output."""
    listing = json.loads(run("xcrun", "simctl", "list", "devices", "-j"))
    for devices in listing["devices"].values():
        for device in devices:
            if device["udid"] == udid:
                return device["name"]
    raise SystemExit(f"no simulator with udid {udid}")


def boot(udid: str) -> None:
    """Boot and wait for it to mean something.

    `simctl boot` returns as soon as the boot has started. `bootstatus -b` is
    the one that waits for it to finish; without it every subsequent command
    races the device.
    """
    state = json.loads(run("xcrun", "simctl", "list", "devices", "-j"))
    booted = any(
        device["udid"] == udid and device["state"] == "Booted"
        for devices in state["devices"].values()
        for device in devices
    )
    if not booted:
        run("xcrun", "simctl", "boot", udid)
    run("xcrun", "simctl", "bootstatus", udid, "-b")


def springboard_state(udid: str) -> Path:
    """The Home Screen layout file for this device."""
    listing = json.loads(run("xcrun", "simctl", "list", "devices", "-j"))
    for devices in listing["devices"].values():
        for device in devices:
            if device["udid"] == udid:
                path = Path(device["dataPath"]) / SPRINGBOARD_STATE
                if not path.is_file():
                    raise SystemExit(
                        f"no Home Screen state at {path}\n"
                        "The device has never finished a boot. Run:\n"
                        f"  xcrun simctl boot {udid} && xcrun simctl bootstatus {udid} -b"
                    )
                return path
    raise SystemExit(f"no simulator with udid {udid}")


def set_widget_size(udid: str, size: str) -> None:
    """Put the widget on Home Screen page 1 at `size`.

    The device must be shut down. SpringBoard writes this file on exit, so an
    edit made while it is running is overwritten by the version in memory — and
    the capture then shows the old size, which looks like the edit silently
    failing rather than being undone.

    An existing entry is resized in place; a device that has never had the
    widget placed gets one written from scratch.

    **The widget's page is left as the only page**, not merely cleared. There is
    no `simctl` gesture or page-navigation verb, so whichever page SpringBoard
    happens to be showing is the one that gets captured — and installing the app
    parks it on the page the new icon landed on, which on this device it then
    kept across two further reboots. The result is a screenshot of a Home Screen
    full of Apple's apps: valid, convincing, and missing the entire subject.

    iOS then reflows the other apps onto this page rather than retiring them to
    the App Library, so the listing shows a populated Home Screen with the widget
    at the top. That was put to Nick on 2026-08-24 and chosen deliberately over
    the emptier picture: leaving the widget alone requires a second page for the
    apps to live on, and a second page is precisely what the device parks on.
    """
    path = springboard_state(udid)
    state = plistlib.loads(path.read_bytes())

    existing = next(
        (
            entry
            for page in state.get("iconLists") or []
            for entry in page
            if isinstance(entry, dict) and entry.get("bundleIdentifier") == WIDGET_BUNDLE_ID
        ),
        None,
    )
    if existing is not None:
        existing["gridSize"] = size
        state["iconLists"] = [[existing]]
        action = "resized"
    else:
        state["iconLists"] = [
            [{
                "allowsExternalSuggestions": True,
                "allowsSuggestions": True,
                "bundleIdentifier": WIDGET_BUNDLE_ID,
                "containerBundleIdentifier": APP_BUNDLE_ID,
                "displayIdentifier": str(uuid.uuid4()).upper(),
                "elementType": "widget",
                "gridSize": size,
                "iconType": "custom",
                "uniqueIdentifier": str(uuid.uuid4()).upper(),
                "widgetIdentifier": WIDGET_KIND,
            }]
        ]
        action = "placed"

    # SpringBoard pairs this list with `iconLists` positionally and drops pages
    # it cannot identify, so it has to shrink with them.
    identifiers = state.get("listUniqueIdentifiers")
    if isinstance(identifiers, list) and len(identifiers) > 1:
        state["listUniqueIdentifiers"] = identifiers[:1]

    path.write_bytes(plistlib.dumps(state))
    print(f"  {action} {WIDGET_KIND} on page 1 at {size}")


def confirm_widget_size(udid: str, size: str) -> None:
    """Prove the layout survived the boot.

    SpringBoard validates what it reads and drops anything it does not like —
    a family the widget does not declare, a malformed entry — without saying so.
    What it writes back after booting is the honest answer, and it is the
    difference between a screenshot of the wrong size and one of nothing at all.
    """
    state = plistlib.loads(springboard_state(udid).read_bytes())
    page_one = (state.get("iconLists") or [[]])[0]
    entry = next(
        (
            e
            for e in page_one
            if isinstance(e, dict) and e.get("bundleIdentifier") == WIDGET_BUNDLE_ID
        ),
        None,
    )
    if entry is None:
        raise SystemExit(
            f"SpringBoard dropped {WIDGET_KIND} from page 1 on {udid}.\n"
            f"Check that NoSpoilersWidget declares the {size} family in supportedFamilies."
        )
    if entry.get("gridSize") != size:
        raise SystemExit(
            f"asked for {size}, SpringBoard kept {entry.get('gridSize')!r} on {udid}"
        )


def confirm_fixture_intact(cache_file: Path, seeded: str) -> None:
    """Prove the widget did not replace the fixture with the real calendar.

    `resolveWidgetData()` in NoSpoilersWidget.swift falls back to the network
    when the cache is missing or empty and writes what it fetches back — the
    widget deliberately does not need the app to have run first. On a device
    seeing this widget for the first time that fetch happens before any fixture
    exists, and every later run then races it.

    The failure is the dangerous kind: a screenshot of today's calendar is
    correct-looking and internally consistent, and nothing marks it as wrong
    until a race name changes between two runs of the same command.

    This catches the cache being overwritten. It does NOT catch a stale
    *timeline* — a cache holding the fixture while WidgetKit still draws a
    picture generated hours ago from real data. Only `--install` invalidates
    that; see the module docstring.
    """
    if cache_file.read_text() == seeded:
        return
    raise SystemExit(
        f"the fixture at {cache_file} was replaced while the device booted.\n"
        "The widget fetched the live calendar and wrote it back, so the capture would\n"
        "show today's races rather than the fixture. Re-run the same command: the cache\n"
        "is no longer empty, so this time the widget reads it instead of the network."
    )


def app_group_container(udid: str) -> Path:
    """Where the widget reads its cache from.

    Never fall back to the app's own data container when this fails. The widget
    reads the group container, so a fixture written anywhere else produces a
    screenshot of stale data that looks entirely correct.
    """
    path = run("xcrun", "simctl", "get_app_container", udid, APP_BUNDLE_ID, APP_GROUP_ID).strip()
    if not path:
        raise SystemExit(f"no App Group container for {APP_GROUP_ID} on {udid}")
    container = Path(path)
    if not container.is_dir():
        raise SystemExit(f"App Group container is not a directory: {container}")
    return container


def ensure_installed(udid: str, install: Path | None) -> None:
    """Install if asked, then prove it is there.

    The proof is separate from the install on purpose: `simctl install` succeeds
    against a bundle whose identifier is not the one we are about to look up.
    """
    if install is not None:
        if not install.is_dir():
            raise SystemExit(f"--install is not an app bundle: {install}")
        run("xcrun", "simctl", "install", udid, str(install))

    result = subprocess.run(
        ("xcrun", "simctl", "get_app_container", udid, APP_BUNDLE_ID, "app"),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(
            f"{APP_BUNDLE_ID} is not installed on {udid}\n"
            "Build it and pass --install, e.g.\n"
            "  xcodebuild build -project NoSpoilers/NoSpoilers.xcodeproj -scheme NoSpoilersApp \\\n"
            f"    -destination 'id={udid}' \\\n"
            "    -derivedDataPath tmp/DerivedData/NoSpoilersApp-sim COMPILER_INDEX_STORE_ENABLE=NO\n"
            f"  scripts/screenshots.py --device {udid} \\\n"
            "    --install tmp/DerivedData/NoSpoilersApp-sim/Build/Products/Debug-iphonesimulator/NoSpoilersApp.app\n"
            "\n"
            "Do NOT add CODE_SIGNING_ALLOWED=NO. It strips the App Group entitlement, and the\n"
            "seed step then has no shared container to write to. Use default simulator signing.\n"
            "Device names are not unique on this machine, so pass a UDID to -destination too."
        )


def fixture_json(now: datetime) -> str:
    """The fixture, encoded the way ScheduleCache writes it.

    Envelope shape and `.iso8601` dates come from
    NoSpoilersCore/Sources/NoSpoilersCore/ScheduleCache.swift. Swift's
    `.iso8601` strategy emits and expects whole seconds with a `Z`, which is
    what `timespec="seconds"` produces — fractional seconds fail to decode.
    """
    def stamp(offset: timedelta) -> str:
        return (now + offset).astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")

    weekends = [
        {
            "round": weekend["round"],
            "name": weekend["name"],
            "location": weekend["location"],
            "sessions": {kind: stamp(offset) for kind, offset in weekend["sessions"].items()},
        }
        for weekend in FIXTURE
    ]
    envelope = {"cachedAt": stamp(timedelta()), "weekends": weekends}
    return json.dumps(envelope, indent=2)


def capture(
    device: str,
    out_dir: Path,
    install: Path | None,
    expected: list[tuple[int, int]],
    widget_size: str | None,
    dry_run: bool,
) -> Path:
    udid = device_udid(device)
    # Name the file after the device, not after whatever the caller typed — a
    # UDID passed to disambiguate would otherwise produce a filename nobody can
    # match to a screenshot slot in App Store Connect. The size joins it because
    # three sizes of one device would otherwise overwrite each other.
    slug = "".join(c if c.isalnum() else "-" for c in device_name(udid).lower()).strip("-")
    while "--" in slug:
        slug = slug.replace("--", "-")
    if widget_size:
        slug = f"{slug}-{widget_size}"
    destination = out_dir / f"{slug}.png"

    if dry_run:
        print(f"{device} [{udid}]")
        print(f"  seed    <app group>/{CACHE_FILENAME}")
        if widget_size:
            print(f"  place   {WIDGET_KIND} on page 1 at {widget_size}")
        print(f"  reboot  shutdown, boot, settle {SETTLE_SECONDS}s")
        print(f"  capture {destination}")
        return destination

    boot(udid)
    ensure_installed(udid, install)

    cache_file = app_group_container(udid) / CACHE_FILENAME
    seeded = fixture_json(datetime.now(timezone.utc))
    cache_file.write_text(seeded)
    print(f"  seeded {cache_file}")

    # Reboot rather than launch: see the module docstring. The layout edit goes
    # between the shutdown and the boot — SpringBoard is not running to undo it,
    # and the boot is what reads it back.
    run("xcrun", "simctl", "shutdown", udid)
    if widget_size:
        set_widget_size(udid, widget_size)
    boot(udid)
    if widget_size:
        confirm_widget_size(udid, widget_size)
    time.sleep(SETTLE_SECONDS)
    confirm_fixture_intact(cache_file, seeded)

    out_dir.mkdir(parents=True, exist_ok=True)
    run("xcrun", "simctl", "io", udid, "screenshot", str(destination))
    if not destination.is_file():
        raise SystemExit(f"simctl reported success but wrote nothing to {destination}")
    print(f"  captured {destination}")
    check_size(destination, expected)
    return destination


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--device", action="append", required=True, help="simulator name; repeatable")
    parser.add_argument("--out", type=Path, default=Path("tmp/screenshots"), help="output directory")
    parser.add_argument("--install", type=Path, help="path to NoSpoilersApp.app to install first")
    parser.add_argument(
        "--expect",
        action="append",
        default=[],
        metavar="WxH",
        help="accepted pixel size, repeatable; the capture fails if it matches none",
    )
    parser.add_argument(
        "--widget-size",
        choices=WIDGET_SIZES,
        help="place the widget on Home Screen page 1 at this size before capturing",
    )
    parser.add_argument("--dry-run", action="store_true", help="print the plan and do nothing")
    args = parser.parse_args()

    expected: list[tuple[int, int]] = []
    for value in args.expect:
        parts = value.lower().split("x")
        if len(parts) != 2 or not all(p.isdigit() for p in parts):
            raise SystemExit(f"--expect wants WxH, got {value!r}")
        expected.append((int(parts[0]), int(parts[1])))

    for device in args.device:
        print(device)
        capture(device, args.out, args.install, expected, args.widget_size, args.dry_run)

    if not args.dry_run:
        print(
            "\nCheck every image before uploading. A device with no widget on its Home Screen\n"
            "produces a perfectly valid screenshot without one, which looks exactly like success."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())

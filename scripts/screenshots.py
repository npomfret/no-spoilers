#!/usr/bin/env python3
"""Capture App Store screenshots from a simulator, against fixture data.

The point of this script is that the same command produces the same picture in
March and in August. Screenshots taken against the live calendar do not: out of
season the widget correctly renders its off-season state, and mid-season it
renders whatever race happens to be next.

What it does, per device:

    write fixture -> shutdown -> boot -> settle -> screenshot

Two of those steps look redundant and are not.

**The app is never launched.** `ScheduleStore.refresh()` fetches from the network
and then calls `cache.save(...)` unconditionally — it does not consult
`isFresh` — so the first refresh replaces the fixture with the real calendar.
Launching the app to "make it pick up the data" destroys the data.

**The reboot is the reload.** Nothing on the command line can ask WidgetKit for a
new timeline. Booting does: the Home Screen comes up and every widget on it is
asked to render. The widget reads the App Group cache directly and only falls
back to the network when that cache is empty, so a seeded fixture is what it
draws.

Placing the widget on the Home Screen is manual and one-time per simulator —
there is no `simctl` verb for it. See tasks/18-screenshot-seed-and-capture.md.

Stdlib only, like the other Python here. No venv, no install.

Pick the device by the pixel size the listing's slot wants, not by what is
newest. As of 2026-08-13 the iPhone slot on this listing accepts 1242x2688 or
1284x2778 — the 6.5"/6.7" sizes — so `iPhone 11 Pro Max` (natively 1242x2688) is
the device, and `iPhone 17 Pro Max` at 1320x2868 is refused. Pass `--expect` and
find out in seconds rather than at upload.

Usage:
    scripts/screenshots.py --device "iPhone 11 Pro Max" --expect 1242x2688
    scripts/screenshots.py --device "iPhone 11 Pro Max" --device "iPad Pro 13-inch (M5)"
    scripts/screenshots.py --device "iPhone 11 Pro Max" --install path/to/NoSpoilersApp.app
    scripts/screenshots.py --device "iPhone 11 Pro Max" --dry-run

`--dry-run` is not the default, unlike testflight_distribute.py. That script
defaults to dry-run because it writes to App Store Connect, where a mistake is
public. This one writes to a simulator and a local directory, and rebooting a
simulator you own is not a thing to be protected from.
"""

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

APP_BUNDLE_ID = "pomocorp.NoSpoilers.NoSpoilersMac"
APP_GROUP_ID = "group.pomocorp.no-spoilers"
CACHE_FILENAME = "schedule-cache.json"

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
            "    -destination 'platform=iOS Simulator,name=<device>' \\\n"
            "    -derivedDataPath tmp/DerivedData/NoSpoilersApp-sim CODE_SIGNING_ALLOWED=NO\n"
            "  scripts/screenshots.py --device <device> \\\n"
            "    --install tmp/DerivedData/NoSpoilersApp-sim/Build/Products/Debug-iphonesimulator/NoSpoilersApp.app"
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
    dry_run: bool,
) -> Path:
    udid = device_udid(device)
    # Name the file after the device, not after whatever the caller typed — a
    # UDID passed to disambiguate would otherwise produce a filename nobody can
    # match to a screenshot slot in App Store Connect.
    slug = "".join(c if c.isalnum() else "-" for c in device_name(udid).lower()).strip("-")
    while "--" in slug:
        slug = slug.replace("--", "-")
    destination = out_dir / f"{slug}.png"

    if dry_run:
        print(f"{device} [{udid}]")
        print(f"  seed    <app group>/{CACHE_FILENAME}")
        print(f"  reboot  shutdown, boot, settle {SETTLE_SECONDS}s")
        print(f"  capture {destination}")
        return destination

    boot(udid)
    ensure_installed(udid, install)

    cache_file = app_group_container(udid) / CACHE_FILENAME
    cache_file.write_text(fixture_json(datetime.now(timezone.utc)))
    print(f"  seeded {cache_file}")

    # Reboot rather than launch: see the module docstring.
    run("xcrun", "simctl", "shutdown", udid)
    boot(udid)
    time.sleep(SETTLE_SECONDS)

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
        capture(device, args.out, args.install, expected, args.dry_run)

    if not args.dry_run:
        print(
            "\nCheck every image before uploading. A device with no widget on its Home Screen\n"
            "produces a perfectly valid screenshot without one, which looks exactly like success."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())

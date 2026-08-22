#!/usr/bin/env python3
"""Capture the macOS listing screenshot: the menu bar, the popover, real data of ours.

The Mac listing has never had a screenshot of the app. What is on it is one
1280x800 file called `Gemini_Generated_Image_utojutojutojutoj.jpg` — a picture
of an idea of the app, uploaded because taking a real one had no tooling and
`screenshots.py` is a simulator script that cannot help here. Guideline 2.3.3
wants screenshots that show the app in use, and this app is arguing with App
Review already.

macOS is a different problem from iOS in every part except the fixture:

- **There is no simulator.** This drives the real app on this machine, so it
  quits your running copy, overwrites the shared cache with the fixture, and
  leaves the app running afterwards holding fixture data until its next
  successful fetch. None of that is destructive and all of it is visible.
- **There is no widget to render from the cache.** The picture only exists
  while the app is running, so unlike `screenshots.py` this one *must* launch
  it — and launching it starts a fetch that overwrites the fixture. See below.
- **The popover cannot be opened from a command.** It is an `NSPopover` shown
  by `togglePopover` on a click, and there is no URL scheme and no scripting
  dictionary. System Events clicks the status item, which needs Accessibility.
- **The capture is a region of the real screen**, so whatever is behind the
  popover is in the shot. Set a plain desktop picture before a real run.

## Two things it refuses, both learned from the first real run

**It captures the build this checkout makes, or nothing.** The first run
photographed `/Applications/No Spoilers.app`, which is `1.0.21` — the last
release, from before the 4.1(a) sweep — and the picture has the owned wordmark
in the menu bar and again at the top of the popover. It is a perfect screenshot
of the asset that was deleted on 2026-08-13 for being the thing App Review kept
rejecting, and every part of the run reported success. So the app's
`CFBundleShortVersionString` and `CFBundleVersion` are checked against what
`_version.sh` says this checkout holds, and a mismatch stops the run.

**It refuses to run with the schedule feed reachable**, unless told otherwise,
because a run with the network up is not reproducible. See below.

## The fetch is not suppressed. It is refused, then detected.

`ScheduleStore.refresh()` fetches and saves unconditionally, and the popover
opening triggers another one — so a successful fetch replaces the fixture and
the capture shows the live calendar. `screenshots.py` avoids this by never
launching the app, which is not available here.

Suppressing it needs a launch-argument branch inside `ScheduleStore`. That trade
was weighed on 2026-08-18 and declined, with the note to revisit it "as a product
capability — an offline mode — rather than as test scaffolding". This does not
reopen it unilaterally. **What it does instead is read the cache back after the
capture and say which data you got.** A tool that cannot guarantee the fixture
but always tells you the truth about it is worth more than one that quietly
does neither.

`performRefresh` keeps the published state when the fetch throws, so the way to
make a run deterministic today is to **turn the network off** — which is why
this checks the feed host first and stops if it answers.

The read-back is kept as a second line of defence and is deliberately not
trusted on its own: on the first run it reported the fixture intact for a
picture of the live calendar, because the fetch had not finished writing by the
time it looked. A check that can be beaten by timing is worth having and is not
worth believing.

Usage:
    scripts/mac_screenshots.py --dry-run
    scripts/mac_screenshots.py
    scripts/mac_screenshots.py --expect 2560x1600
    scripts/mac_screenshots.py --region 1440x900 --out tmp/screenshots

Stdlib only, and it imports the fixture from `screenshots.py` rather than
repeating it — the two listings should show the same weekend, and a second copy
of the fixture is how they stop.
"""

import argparse
import json
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from screenshots import (  # noqa: E402
    APP_GROUP_ID,
    CACHE_FILENAME,
    check_size,
    fixture_json,
)

# The installed app. A menu bar app has no window to attach to, so there is no
# way to drive the copy in DerivedData without installing it first.
DEFAULT_APP = Path("/Applications/No Spoilers.app")

# The process name, which is the binary's name and not the app's. System Events
# wants this one and the two differ here.
PROCESS = "NoSpoilersMac"

# macOS App Store screenshot sizes, in points. `screencapture -R` takes points
# and writes the backing store, which is 2x on every Mac this will run on, so a
# 1280x800 region lands as 2560x1600 — both are sizes App Store Connect accepts.
DEFAULT_REGION = (1280, 800)

# How long to let the popover draw before capturing. It renders its countdowns
# on appearance and the flags load from the asset catalogue; a capture taken
# immediately catches a half-drawn row.
SETTLE_SECONDS = 3

# How long to wait for the status item to exist after launch.
LAUNCH_TIMEOUT = 20

# The host `ScheduleFetcher.feedRoot` reads from. Reachability here is the
# difference between a reproducible capture and a photograph of today.
FEED_HOST = "raw.githubusercontent.com"

# The app says which data it settled on, and this is the only honest way to find
# out. `ScheduleStore.performRefresh` writes `refresh complete` when the fetch
# won and `refresh failed` when it did not, so the picture's provenance is a
# fact the app states rather than something to infer from a file.
LOG_PREDICATE = 'subsystem == "pomocorp.NoSpoilers" AND category == "store"'


def osascript(script: str, timeout: int = 20) -> str:
    """One AppleScript, with its error text promoted.

    Accessibility failures arrive here as ordinary execution errors mentioning
    "not allowed assistive access", which is a permission to grant rather than a
    bug to fix — so it is named in the message instead of being re-raised bare.
    """
    result = subprocess.run(
        ("osascript", "-e", script), capture_output=True, text=True, timeout=timeout
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        if "assistive access" in detail or "1002" in detail:
            raise SystemExit(
                f"{detail}\n\n"
                "This needs Accessibility. System Settings > Privacy & Security > "
                "Accessibility, and switch on whatever is running this — Terminal, iTerm, "
                "or your editor. There is no other way to open the popover: it is shown by a "
                "click handler, and the app has no URL scheme and no scripting dictionary."
            )
        raise SystemExit(f"osascript failed: {detail}")
    return result.stdout.strip()


def project_version() -> tuple[str, str]:
    """What this checkout builds, from the one place that knows.

    Shelled out to `_version.sh` rather than parsed here. The pbxproj is already
    read by `current_marketing_version` and `current_build_number`, and a second
    grep of the same file in another language is how the release path and the
    screenshot path start disagreeing about what version this is.
    """
    script = Path(__file__).resolve().parent / "_version.sh"
    result = subprocess.run(
        ("bash", "-c", f'source "{script}"; current_marketing_version; echo; current_build_number'),
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise SystemExit(f"could not read the project version: {result.stderr.strip()}")
    version, build = result.stdout.strip().split("\n")
    return version.strip(), build.strip()


def app_version(app: Path) -> tuple[str, str]:
    """The installed bundle's marketing version and build number."""
    plist = app / "Contents/Info.plist"
    def read(key: str) -> str:
        result = subprocess.run(
            ("/usr/libexec/PlistBuddy", "-c", f"Print :{key}", str(plist)),
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            raise SystemExit(f"{plist} has no {key}")
        return result.stdout.strip()
    return read("CFBundleShortVersionString"), read("CFBundleVersion")


def check_app_is_current(app: Path) -> None:
    """Refuse to photograph a build that is not the one this checkout makes.

    **The failure this exists for is not hypothetical and is not subtle once
    seen.** The first run of this script captured the installed `1.0.21`, which
    still contains the wordmark deleted on 2026-08-13 under 4.1(a) — the picture
    has it in the menu bar and again in the popover header. Every step reported
    success, and the output was a listing screenshot of the exact asset three
    rejections were about.
    """
    installed = app_version(app)
    wanted = project_version()
    if installed == wanted:
        print(f"app      {app.name} {installed[0]} ({installed[1]})")
        return
    raise SystemExit(
        f"{app} is {installed[0]} ({installed[1]}) and this checkout builds "
        f"{wanted[0]} ({wanted[1]}).\n"
        "A screenshot of an older build is a screenshot of an older listing — 1.0.21 still has\n"
        "the wordmark that was removed for 4.1(a). Build and install the current one:\n"
        "  scripts/verify-mac-build.sh\n"
        "  then copy the built NoSpoilersMac.app over the installed one, or pass --app to point\n"
        "  at it directly."
    )


def feed_reachable(timeout: float = 3.0) -> bool:
    """Whether a refresh would succeed, which decides whether this run repeats."""
    try:
        with socket.create_connection((FEED_HOST, 443), timeout=timeout):
            return True
    except OSError:
        return False


def app_running() -> bool:
    return subprocess.run(("pgrep", "-x", PROCESS), capture_output=True).returncode == 0


def quit_app() -> None:
    """Stop the running copy, so it cannot overwrite the fixture we are about to write.

    SIGTERM rather than a scripted quit: the app is not scriptable, and a menu
    bar app holding no document has nothing to lose. It is relaunched below.
    """
    if not app_running():
        return
    subprocess.run(("pkill", "-x", PROCESS), capture_output=True)
    for _ in range(20):
        if not app_running():
            return
        time.sleep(0.25)
    raise SystemExit(f"{PROCESS} would not quit; stop it by hand and re-run")


def cache_path() -> Path:
    """Where the Mac app and the widget share the schedule.

    Not derived from the app bundle: the container belongs to the App Group and
    exists whether or not the app is installed. If it is missing the app has
    never run on this machine, and seeding a directory that nothing reads would
    produce a screenshot of an empty state that looks like a rendering bug.
    """
    container = Path.home() / "Library/Group Containers" / APP_GROUP_ID
    if not container.is_dir():
        raise SystemExit(
            f"no App Group container at {container}\n"
            "Launch the app once so macOS creates it."
        )
    return container / CACHE_FILENAME


def wait_for_status_item() -> None:
    """Block until the app has put its item in the menu bar.

    `open` returns as soon as the launch begins. The status item appears a
    moment later, and clicking before it exists is an AppleScript index error
    rather than a wait.
    """
    deadline = time.time() + LAUNCH_TIMEOUT
    while time.time() < deadline:
        try:
            count = osascript(
                f'tell application "System Events" to tell process "{PROCESS}" '
                "to get count of menu bars"
            )
            if count.isdigit() and int(count) >= 2:
                return
        except SystemExit:
            # The process is not there yet, which is the ordinary case for the
            # first second. A permission failure raises again below and is not
            # swallowed by the loop, because it will not start passing.
            pass
        time.sleep(0.5)
    raise SystemExit(
        f"{PROCESS} has no status item {LAUNCH_TIMEOUT}s after launch.\n"
        "The app is running but has not reached the menu bar, or another copy is holding it."
    )


def screen_width() -> int:
    """The main display's width in points, taken from the menu bar that spans it.

    Read rather than assumed. This machine reports 1800 points against a 3024
    pixel panel — a scaled Retina mode, so neither the pixel size nor a guessed
    2x gives the number `screencapture -R` wants.
    """
    size = osascript(
        f'tell application "System Events" to tell process "{PROCESS}" to get size of menu bar 1'
    )
    width = size.split(",")[0].strip()
    if not width.isdigit():
        raise SystemExit(f"could not read the menu bar width, got {size!r}")
    return int(width)


def open_popover() -> None:
    """Click the status item.

    `menu bar 2` is the system status bar as this process sees it — its own item
    and nothing else — so item 1 of it is ours without having to match a title.
    """
    osascript(
        f'tell application "System Events" to tell process "{PROCESS}" '
        "to click menu bar item 1 of menu bar 2"
    )


def capture(destination: Path, region: tuple[int, int]) -> None:
    """A region of the real screen, anchored to the top-right corner.

    Top-right because that is where a menu bar app lives: the shot contains the
    status item, the popover hanging off it, and the corner of the desktop, which
    is what the product actually looks like in use. Anchoring also makes the
    frame reproducible without knowing where the popover landed.
    """
    width, height = region
    left = max(0, screen_width() - width)
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ("screencapture", "-x", "-R", f"{left},0,{width},{height}", str(destination)),
        check=True,
    )
    if not destination.is_file():
        raise SystemExit(f"screencapture reported success and wrote nothing to {destination}")


def start_log() -> subprocess.Popen:
    """Attach to the app's store channel before it launches.

    Order matters for the same reason it does in `alerts_check.py`: the line
    worth reading is written a second into launch, and a stream attached
    afterwards sees nothing. The banner `log stream` prints before its first
    record is what says it is attached, so this waits for that rather than
    sleeping a guessed interval.
    """
    process = subprocess.Popen(
        ("log", "stream", "--style", "ndjson", "--predicate", LOG_PREDICATE),
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
    )
    process.stdout.readline()
    return process


def refresh_outcome(process: subprocess.Popen) -> str | None:
    """What the app says it settled on: `refresh complete`, `refresh failed`, or nothing.

    **This replaced reading the cache file back, which was wrong on both of the
    first two runs.** It reported the fixture intact for a picture of the live
    calendar — once because the fetch had not finished writing when it looked,
    and once because the app was running from a path where the save to the group
    container failed, so the screen held live data the disk never received. A
    file is evidence of what was written; only the app knows what it drew.
    """
    process.terminate()
    output, _ = process.communicate()
    outcome = None
    for line in (output or "").splitlines():
        try:
            entry = json.loads(json.loads(line)["eventMessage"])
        except (json.JSONDecodeError, KeyError, TypeError):
            continue
        message = entry.get("msg")
        if message in ("refresh complete", "refresh failed, serving cache",
                       "refresh failed, keeping published state"):
            outcome = message
    return outcome


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--app", type=Path, default=DEFAULT_APP, help=f"default {DEFAULT_APP}")
    parser.add_argument("--out", type=Path, default=Path("tmp/screenshots"))
    parser.add_argument("--region", default="x".join(str(n) for n in DEFAULT_REGION),
                        metavar="WxH", help="capture region in points, top-right anchored")
    parser.add_argument("--expect", action="append", default=[], metavar="WxH",
                        help="accepted pixel size, repeatable; the capture fails if it matches none")
    parser.add_argument("--allow-network", action="store_true",
                        help="capture with the feed reachable. The app will refetch and the "
                             "picture will show today's calendar rather than the fixture.")
    parser.add_argument("--dry-run", action="store_true")
    arguments = parser.parse_args()

    def pixels(value: str) -> tuple[int, int]:
        parts = value.lower().split("x")
        if len(parts) != 2 or not all(p.isdigit() for p in parts):
            raise SystemExit(f"wanted WxH, got {value!r}")
        return int(parts[0]), int(parts[1])

    region = pixels(arguments.region)
    expected = [pixels(value) for value in arguments.expect]
    destination = arguments.out / "macos-menu-bar.png"

    if not arguments.app.is_dir():
        raise SystemExit(f"no app at {arguments.app}. Install it, or pass --app.")

    check_app_is_current(arguments.app)

    # Before anything is quit or overwritten. A reachable feed means the app
    # refetches on launch and again when the popover opens, and the capture is
    # of today rather than of the fixture.
    if feed_reachable():
        if not arguments.allow_network:
            raise SystemExit(
                f"{FEED_HOST} is reachable, so the app will refetch and this capture will not\n"
                "reproduce — it will show whatever weekend is next today.\n\n"
                "Turn the network off and run it again: the fetch then fails, `performRefresh`\n"
                "keeps the published state, and the fixture is what gets photographed.\n"
                "Or pass --allow-network if a picture of today is what you want."
            )
        print(f"!        {FEED_HOST} is reachable and --allow-network was given")
    else:
        print(f"offline  {FEED_HOST} unreachable, so the fixture will survive the launch")

    if arguments.dry_run:
        print(f"quit     {PROCESS}" + ("" if app_running() else "  (not running)"))
        print(f"seed     {cache_path()}")
        print(f"launch   {arguments.app.name}, wait for the status item")
        print(f"click    menu bar item, settle {SETTLE_SECONDS}s")
        print(f"capture  {region[0]}x{region[1]} points, top-right -> {destination}")
        print("verify   the cache still holds the fixture")
        return 0

    quit_app()

    path = cache_path()
    path.write_text(fixture_json(datetime.now(timezone.utc)))
    print(f"seeded {path}")

    stream = start_log()
    subprocess.run(("open", "-a", str(arguments.app)), check=True)
    wait_for_status_item()
    open_popover()
    time.sleep(SETTLE_SECONDS)

    capture(destination, region)
    print(f"captured {destination}")
    check_size(destination, expected)

    outcome = refresh_outcome(stream)
    if outcome is None:
        print(
            "\n! The app said nothing on its store channel, so what it drew is unknown.\n"
            "  Check the picture against the fixture by eye before using it."
        )
    elif outcome == "refresh complete":
        print(
            "\n! The app fetched successfully, so this is a picture of today's calendar and\n"
            "  not of the fixture. It will not reproduce. Turn the network off and run again."
        )
    else:
        print(f"\nThe app reports `{outcome}`, so this is the fixture and it reproduces.")

    print(
        "\nThe app is still running and holding whatever is in the cache now; its next\n"
        "successful fetch restores the real calendar. Look at the image before uploading —\n"
        "the desktop behind the popover is in the shot."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

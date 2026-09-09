#!/usr/bin/env python3
"""Capture the macOS listing screenshot: the menu bar, the popover, real data of ours.

The Mac listing has never had a screenshot of the app. What is on it is one
1280x800 file called `Gemini_Generated_Image_utojutojutojutoj.jpg` — a picture
of an idea of the app, uploaded because taking a real one had no tooling and
`screenshots.py` is a simulator script that cannot help here. Guideline 2.3.3
wants screenshots that show the app in use, and this app is arguing with App
Review already.

macOS is a different problem from iOS in every part:

- **There is no simulator.** This drives the real app on this machine, so it
  quits your running copy and leaves the app running afterwards. Nothing here
  writes to the app's data any more — see below for what it cost to learn that.
- **There is no widget to render from a cache.** The picture only exists while
  the app is running, so unlike `screenshots.py` this one *must* launch it —
  and launching it starts a fetch. See below.
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

## It no longer seeds a fixture, because it could not and should not

The first version wrote `schedule-cache.json` into the App Group container and
expected the app to draw it. **Neither capture ever showed the fixture** — both
showed the live calendar, which was put down to the fetch winning the race.

The real reason surfaced on 2026-08-23, in the app's own log:

    cache load failed at launch   Code=257  file couldn't be opened
    cache save failed             Code=513  you don't have permission to save

The Mac app is sandboxed and this script is not. A file written into a group
container by an unsandboxed process is one the sandboxed app can neither read
nor replace, so the seed was invisible to the app and, worse, **it displaced the
cache the app maintains**: from the moment of the first run the Mac app had no
readable cache and could not write a new one. It carried on working — it refetches
on launch and keeps published state when the cache fails — which is why nothing
looked wrong for a day.

So the seeding is gone rather than fixed. Making it work means writing the file
*as the app*, which means the app growing a way to be told what to hold, which is
the offline-mode seam that `screenshots.py` declined to open on 2026-08-18 and
that this script has no business opening on its own.

**What is left is honest**: this captures whatever the app is showing, and says
which calendar that was. For a listing screenshot that is a picture of today —
fine for a menu bar app whose subject is this weekend, and not reproducible.

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

`performRefresh` keeps the published state when the fetch throws, so with the
network off the app draws whatever cache it already holds — its own, now that
nothing here overwrites it. That is still not the fixture, and this says so.

The read-back is kept as a second line of defence and is deliberately not
trusted on its own: on the first run it reported the fixture intact for a
picture of the live calendar, because the fetch had not finished writing by the
time it looked. A check that can be beaten by timing is worth having and is not
worth believing.

## `--appearance` flips the whole desktop, and puts it back

The popover follows the system appearance since 2026-09-05, and there is no
per-app override for a menu bar app: the only way to see it dark is to make the Mac
dark. `--appearance dark` does that through System Events' appearance preferences,
relaunches the app so the popover draws fresh, captures, and restores whatever the
appearance was before — in a `finally`, so a failed capture does not leave you in the
wrong one. The capture is named for the appearance (`macos-menu-bar-dark.png`) so a
light and a dark run sit side by side. Without the flag nothing is flipped and the
file keeps its listing name.

## `--mask` paints out everything that is not the app

The capture is a region of the real screen, and the listing wants the app and
nothing else. Setting a plain desktop first was the instruction until
2026-09-06, when it turned out not to be something the machine could simply be
asked for. So `--mask` keeps two things — the status item, and the popover
hanging off it — and paints over the rest: a plain slate ground, the menu bar
strip in its own sampled colour with only our item on it, and a drawn shadow
under the popover. Both regions come from Accessibility, the same way the
click does, so nothing is guessed about where the popover landed.

**The popover's AX frame is its window, not its body.** The window carries the
arrow at the top and about 13pt of shadow margin on every side, and the first
composite pasted that margin back with the desktop still in it. The crop is
inset to the visible body, with rounded corners a shade larger than the real
ones so the real corner's edge is under the mask, and the arrow is a triangle
from the item's centre to the body's top.

The compositing is CoreGraphics, reached through `osascript -l JavaScript`,
which this script already needs for the click. Pillow was the obvious tool and
is not used: the Python here is stdlib-only, no venv, no install, and a
screenshot script is not the place to end that.

Usage:
    scripts/mac_screenshots.py --dry-run
    scripts/mac_screenshots.py
    scripts/mac_screenshots.py --expect 2560x1600
    scripts/mac_screenshots.py --region 1440x900 --out tmp/screenshots
    scripts/mac_screenshots.py --appearance dark --allow-network
    scripts/mac_screenshots.py --mask --allow-network        # a listing image, any desktop

Stdlib only. It borrows `check_size` from `screenshots.py` and nothing else:
the two scripts share the App Store's pixel rules and no longer share a fixture,
because this one does not have one.
"""

import argparse
import json
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from screenshots import check_size  # noqa: E402

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

# The backing store is 2x on every Mac this runs on; `capture` says the same.
SCALE = 2

# What `--mask` keeps and draws, in points. The popover window frame from
# Accessibility carries the arrow and a shadow margin outside the visible body;
# these are the measurements that took it back to the body on 2026-09-06.
MASK_INSET = 15          # window frame edge → visible body, left, right, bottom
MASK_ARROW_HEIGHT = 13.5  # window frame top → visible body top
MASK_RADIUS = 17         # a shade larger than the real corner, so its edge is under the mask
MASK_ARROW_HALF = 11
MASK_ITEM_MARGIN = 6     # bar pixels kept either side of the status item
MASK_GROUND = ((92, 104, 122), (52, 60, 74))  # slate, top → bottom

# CoreGraphics through the JavaScript bridge, so the composite needs nothing
# that is not on every Mac. argv: source PNG, destination PNG, JSON spec in
# pixels. The bridge will not turn a JS array into the C array a CGGradient
# wants, hence the gradient painted as bands.
MASK_SCRIPT = r"""
ObjC.import('CoreGraphics'); ObjC.import('ImageIO'); ObjC.import('Foundation');
function run(argv) {
  const spec = JSON.parse(argv[2]);
  const W = spec.width, H = spec.height;
  const src = $.CGImageSourceCreateWithURL($.NSURL.fileURLWithPath(argv[0]), null);
  const img = $.CGImageSourceCreateImageAtIndex(src, 0, null);
  const cs = $.CGColorSpaceCreateDeviceRGB();
  const ctx = $.CGBitmapContextCreate(null, W, H, 8, W * 4, cs, $.kCGImageAlphaPremultipliedLast);
  // CoreGraphics has its origin at the bottom left; the spec is top-left pixels.
  const R = (x, y, w, h) => $.CGRectMake(x, H - y - h, w, h);
  const full = $.CGRectMake(0, 0, W, H);
  const bands = 96;
  for (let i = 0; i < bands; i++) {
    const t = i / (bands - 1);
    const c = [0, 1, 2].map(k => (spec.top[k] + (spec.bottom[k] - spec.top[k]) * t) / 255);
    $.CGContextSetRGBFillColor(ctx, c[0], c[1], c[2], 1);
    const y0 = Math.floor(H * i / bands), y1 = Math.ceil(H * (i + 1) / bands);
    $.CGContextFillRect(ctx, R(0, y0, W, y1 - y0));
  }
  const b = spec.bar;
  const column = $.CGImageCreateWithImageInRect(img, $.CGRectMake(b.sampleX, 0, 1, b.height));
  $.CGContextDrawImage(ctx, R(0, 0, W, b.height), column);
  $.CGContextSaveGState(ctx);
  $.CGContextClipToRect(ctx, R(b.keepX, 0, b.keepWidth, b.height));
  $.CGContextDrawImage(ctx, full, img);
  $.CGContextRestoreGState(ctx);
  const p = spec.popover;
  const body = R(p.x, p.y, p.width, p.height);
  const path = $.CGPathCreateWithRoundedRect(body, p.radius, p.radius, null);
  $.CGContextSaveGState(ctx);
  $.CGContextSetShadowWithColor(ctx, $.CGSizeMake(0, -p.shadowOffset), p.shadowBlur,
                                $.CGColorCreateGenericGray(0, 0.45));
  $.CGContextAddPath(ctx, path); $.CGContextSetRGBFillColor(ctx, 0.5, 0.5, 0.5, 1); $.CGContextFillPath(ctx);
  $.CGContextRestoreGState(ctx);
  $.CGContextSaveGState(ctx);
  $.CGContextAddPath(ctx, path); $.CGContextClip(ctx);
  $.CGContextDrawImage(ctx, full, img);
  $.CGContextRestoreGState(ctx);
  const a = spec.arrow;
  $.CGContextSaveGState(ctx);
  $.CGContextMoveToPoint(ctx, a.x - a.halfWidth, H - p.y - 1);
  $.CGContextAddLineToPoint(ctx, a.x, H - a.tipY);
  $.CGContextAddLineToPoint(ctx, a.x + a.halfWidth, H - p.y - 1);
  $.CGContextClosePath(ctx); $.CGContextClip(ctx);
  $.CGContextDrawImage(ctx, full, img);
  $.CGContextRestoreGState(ctx);
  const out = $.CGBitmapContextCreateImage(ctx);
  const dest = $.CGImageDestinationCreateWithURL($.NSURL.fileURLWithPath(argv[1]), $('public.png'), 1, null);
  $.CGImageDestinationAddImage(dest, out, null);
  if (!$.CGImageDestinationFinalize(dest)) throw new Error('could not write ' + argv[1]);
  return 'ok';
}
"""


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


def system_appearance() -> str:
    """`dark` or `light`, from the preference System Settings writes.

    The key is absent in light mode rather than set to `Light`, so a failed read
    is the ordinary answer and not an error.
    """
    result = subprocess.run(
        ("defaults", "read", "-g", "AppleInterfaceStyle"), capture_output=True, text=True
    )
    return "dark" if result.returncode == 0 and result.stdout.strip() == "Dark" else "light"


def set_system_appearance(appearance: str) -> None:
    """Flip the Mac. Every app on screen follows, including the one this photographs."""
    wanted = "true" if appearance == "dark" else "false"
    osascript(
        f'tell application "System Events" to tell appearance preferences '
        f"to set dark mode to {wanted}"
    )
    print(f"appear   {appearance}")


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


def frame(element: str) -> tuple[int, int, int, int]:
    """Position and size of one of our process's AX elements, in screen points."""
    raw = osascript(
        f'tell application "System Events" to tell process "{PROCESS}" '
        f"to get {{position, size}} of {element}"
    )
    parts = [p.strip() for p in raw.split(",")]
    if len(parts) != 4 or not all(p.lstrip("-").isdigit() for p in parts):
        raise SystemExit(f"could not read the frame of {element}, got {raw!r}")
    x, y, w, h = (int(p) for p in parts)
    return x, y, w, h


def mask(raw: Path, destination: Path, region: tuple[int, int]) -> None:
    """Keep the status item and the popover; paint over everything else.

    Frames are read now, while the popover is open, and converted from screen
    points to capture pixels: the capture is anchored to the top-right corner,
    so its left edge is the screen width less the region width.
    """
    left = screen_width() - region[0]
    ix, _, iw, _ = frame("menu bar item 1 of menu bar 2")
    bar_height = frame("menu bar 1")[3]
    px_, py, pw, ph = frame("pop over 1 of menu bar item 1 of menu bar 2")
    ix -= left
    px_ -= left

    def px(value: float) -> int:
        return int(round(value * SCALE))

    spec = {
        "width": px(region[0]),
        "height": px(region[1]),
        "top": MASK_GROUND[0],
        "bottom": MASK_GROUND[1],
        "bar": {
            "height": px(bar_height),
            # The column just outside the kept margin: the gap between status
            # items, which is bar background and nothing else.
            "sampleX": px(ix - MASK_ITEM_MARGIN - 1),
            "keepX": px(ix - MASK_ITEM_MARGIN),
            "keepWidth": px(iw + 2 * MASK_ITEM_MARGIN),
        },
        "popover": {
            "x": px(px_ + MASK_INSET),
            "y": px(py + MASK_ARROW_HEIGHT),
            "width": px(pw - 2 * MASK_INSET),
            "height": px(ph - MASK_ARROW_HEIGHT - MASK_INSET),
            "radius": px(MASK_RADIUS),
            "shadowOffset": px(6),
            "shadowBlur": px(14),
        },
        "arrow": {"x": px(ix + iw / 2), "halfWidth": px(MASK_ARROW_HALF), "tipY": px(bar_height)},
    }
    result = subprocess.run(
        ("osascript", "-l", "JavaScript", "-e", MASK_SCRIPT, str(raw), str(destination), json.dumps(spec)),
        capture_output=True, text=True, timeout=60,
    )
    if result.returncode != 0 or result.stdout.strip() != "ok":
        raise SystemExit(f"masking failed: {(result.stderr or result.stdout).strip()}")
    print(f"masked   kept the status item and the popover body ({pw - 2 * MASK_INSET}x"
          f"{ph - MASK_ARROW_HEIGHT - MASK_INSET:g} pt), painted over the rest")


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
    parser.add_argument("--appearance", choices=("light", "dark"),
                        help="flip the system appearance for the capture and restore it after; "
                             "the file is named for it")
    parser.add_argument("--mask", action="store_true",
                        help="keep only the status item and the popover, and paint a plain ground "
                             "over the rest of the capture — a listing image from any desktop")
    parser.add_argument("--dry-run", action="store_true")
    arguments = parser.parse_args()

    def pixels(value: str) -> tuple[int, int]:
        parts = value.lower().split("x")
        if len(parts) != 2 or not all(p.isdigit() for p in parts):
            raise SystemExit(f"wanted WxH, got {value!r}")
        return int(parts[0]), int(parts[1])

    region = pixels(arguments.region)
    expected = [pixels(value) for value in arguments.expect]
    suffix = f"-{arguments.appearance}" if arguments.appearance else ""
    destination = arguments.out / f"macos-menu-bar{suffix}.png"

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
                "Turn the network off and run it again: the fetch then fails and the app draws\n"
                "the cache it already holds. Or pass --allow-network if a picture of today is\n"
                "what you want, which for a menu bar app about this weekend it may well be."
            )
        print(f"!        {FEED_HOST} is reachable and --allow-network was given")
    else:
        print(f"offline  {FEED_HOST} unreachable, so the app will draw its own cache")

    if arguments.dry_run:
        if arguments.appearance:
            print(f"appear   {arguments.appearance}, then back to {system_appearance()}")
        print(f"quit     {PROCESS}" + ("" if app_running() else "  (not running)"))
        print(f"launch   {arguments.app.name}, wait for the status item")
        print(f"click    menu bar item, settle {SETTLE_SECONDS}s")
        print(f"capture  {region[0]}x{region[1]} points, top-right -> {destination}")
        if arguments.mask:
            print("mask     keep the status item and the popover, paint over the rest")
        print("verify   which calendar the app says it drew")
        return 0

    quit_app()

    # The flip goes before the launch, so the popover's first draw is in the
    # appearance being photographed rather than a transition out of the other.
    previous_appearance = system_appearance()
    if arguments.appearance and arguments.appearance != previous_appearance:
        set_system_appearance(arguments.appearance)

    try:
        stream = start_log()
        # `open -a` wants a name or an absolute path; a relative `--app` such as the
        # DerivedData build fails with "unable to find application" otherwise.
        subprocess.run(("open", "-a", str(arguments.app.resolve())), check=True)
        wait_for_status_item()
        open_popover()
        time.sleep(SETTLE_SECONDS)

        if arguments.mask:
            # The raw capture is kept only long enough to be masked; the
            # frames must be read now, while the popover is still up.
            with tempfile.TemporaryDirectory() as scratch:
                raw = Path(scratch) / "raw.png"
                capture(raw, region)
                mask(raw, destination, region)
        else:
            capture(destination, region)
        print(f"captured {destination}")
        check_size(destination, expected)
    finally:
        if arguments.appearance and arguments.appearance != previous_appearance:
            set_system_appearance(previous_appearance)

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

    behind = ("the ground behind the popover is painted, so look at its edges" if arguments.mask
              else "the desktop behind the popover is in the shot")
    print(
        "\nThe app is still running and holding whatever is in the cache now; its next\n"
        f"successful fetch restores the real calendar. Look at the image before uploading —\n"
        f"{behind}."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

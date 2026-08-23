#!/usr/bin/env python3
"""Exercise the iOS session alerts on a simulator, and read back what the OS was told.

Notifications are the one part of this product whose failure is completely
silent. Nobody reports an alert they did not get, and "no notification" and "no
session this weekend" look identical from the outside. `SessionAlertPlannerTests`
covers everything that is a function of the schedule; this covers the part that
only exists on a device — that permission is asked for where intended, that the
plan actually reaches `UNUserNotificationCenter`, and how the copy reads when it
arrives.

## What this proves, and what it does not

**It proves the app scheduled something.** `AppLog.alerts` writes one line per
reschedule carrying the count planned and the count the OS reports pending, and
this streams that line back. Two equal non-zero numbers is the evidence that the
planner's output survived the trip; `planned` above `pending` is the OS dropping
requests and is a real finding.

**It does not fire our own alert on demand.** The alerts are built from whatever
schedule the app holds, and a real session is usually days away. Seeding a
fixture with a session two minutes out does not survive contact with the app:
`ScheduleStore.refresh()` fetches and saves unconditionally, so the fixture is
replaced seconds after launch and the alerts are immediately rescheduled off the
real calendar. `scripts/screenshots.py` avoids this by never launching the app,
which is not an option here — the app is the only thing that can schedule.

Suppressing that refresh would take a launch-argument branch inside
`ScheduleStore`. That trade was weighed on 2026-08-18 for the screenshot path and
declined, with the note to revisit it "as a product capability — an offline mode
— rather than as test scaffolding". Nothing here reopens it unilaterally.

**`--push` renders the copy without scheduling it.** It delivers a payload
carrying the exact strings `Strings.Alerts` produces, so the rendering, the
truncation and the tone can be seen without waiting for a session. It exercises
the words, never the timing.

It still needs permission. `simctl push` goes through the ordinary notification
path, so an app iOS has not been told to allow gets its payload accepted and
displayed nowhere — the command succeeds and the screen stays empty. Both
screenshots taken on 2026-08-22 before the prompt was answered showed exactly
that, which is worth knowing before spending twenty minutes on why the banner
is missing.

## Notification permission is a manual tap

There is no `simctl` verb for it — `simctl privacy` covers location, photos and
contacts, and notifications are not among them. The app asks the first time an
alert is switched on, which is `About > Session alerts`, and someone has to
press Allow. This script says so at the point it matters rather than waiting
silently for a line that will never come.

Stdlib only, like the rest of the Python here. Device helpers are imported from
`screenshots.py` rather than repeated: the two scripts must agree about which
simulator they mean, and duplicating `device_udid` is how they stop agreeing.
"""

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from screenshots import (  # noqa: E402
    APP_BUNDLE_ID,
    boot,
    device_name,
    device_udid,
    ensure_installed,
    run,
)

REPO = Path(__file__).resolve().parent.parent
# The alert copy moved to Core on 2026-08-23 when the Mac app got alerts too —
# two apps shipping one set of words, written once. This extractor said it would
# have to move with them, and this is that move.
STRINGS = REPO / "NoSpoilersCore/Sources/NoSpoilersCore/Strings.swift"

# The project's own simulator. Never a stock device name: capturing reboots the
# device and reinstalls the app, and other projects on this machine share the
# stock ones. See CLAUDE.md.
DEFAULT_DEVICE = "NoSpoilers-iPhone"

LOG_PREDICATE = 'subsystem == "pomocorp.NoSpoilers" AND category == "alerts"'

# What a sample alert is about, for --push. Arbitrary and clearly not real: this
# renders copy, and a plausible-looking weekend in a screenshot is the kind of
# thing that ends up somewhere it shouldn't.
SAMPLE_GRAND_PRIX = "Belgian Grand Prix"
SAMPLE_SESSION = "Qualifying"
SAMPLE_MINUTES = 30


def alert_copy() -> dict[str, str]:
    """The two notification bodies, read out of the Swift that produces them.

    Extracted rather than transcribed. A copy of the wording in this file would
    be a second source for the one string in the product a user cannot choose
    not to read, and it would drift the first time the Swift was edited — while
    still producing a perfectly convincing screenshot.
    """
    source = STRINGS.read_text()
    block = re.search(r"\n    public enum Alerts \{\n(.*?)\n    \}\n", source, re.S)
    if not block:
        raise SystemExit(
            f"no `public enum Alerts` block in {STRINGS.relative_to(REPO)}\n"
            "If the strings moved, this extractor has to move with them."
        )
    literals = re.findall(r'"((?:[^"\\]|\\.)*)"', block.group(1))

    def one(needle: str, description: str) -> str:
        found = [text for text in literals if needle in text]
        if len(found) != 1:
            raise SystemExit(
                f"expected exactly one {description} literal containing {needle!r} in "
                f"`public enum Alerts`, found {len(found)}"
            )
        return found[0]

    # Anchored on the interpolation, not on the words. `enum Alerts` also holds
    # the settings-screen intro, which describes these alerts in prose and so
    # contains the same phrases — matching on "has finished" alone found two.
    starting = one("\\(session) starts in \\(minutes)", "start-warning")
    safe = one("\\(session) has finished", "safe-to-watch")

    return {
        "start": starting
        .replace("\\(session)", SAMPLE_SESSION)
        .replace("\\(minutes)", str(SAMPLE_MINUTES)),
        "safe": safe.replace("\\(session)", SAMPLE_SESSION),
    }


def push(udid: str, which: str) -> None:
    """Deliver one notification carrying the real copy. Rendering only."""
    body = alert_copy()[which]
    payload = {
        "Simulator Target Bundle": APP_BUNDLE_ID,
        "aps": {"alert": {"title": SAMPLE_GRAND_PRIX, "body": body}, "sound": "default"},
    }
    with tempfile.NamedTemporaryFile("w", suffix=".apns", delete=False) as handle:
        json.dump(payload, handle)
        path = handle.name

    run("xcrun", "simctl", "push", udid, APP_BUNDLE_ID, path)
    print(f"  pushed  {SAMPLE_GRAND_PRIX}")
    print(f"          {body}")
    print("\nNothing was scheduled — the app was not asked for anything and nothing is pending.")
    print("If no banner appeared, notifications have not been allowed yet: simctl accepts the")
    print("push either way and iOS displays it nowhere.")
    print("\n  In the app:  ⓘ  >  Session alerts  >  turn one on  >  Allow")


def observe(udid: str, seconds: int) -> list[dict]:
    """Relaunch the app with the alerts channel already open, and collect what it says.

    ndjson because `LogChannel` writes one JSON object per line and the useful
    half is inside `eventMessage`; the compact style would need unpicking twice.

    **The order here is the whole point, and getting it wrong cost a day.** The
    line worth reading is written milliseconds into launch — `reschedule` runs
    from `.task` on the root view — so a stream attached afterwards sees an
    empty channel. Worse, `simctl launch` on an app that is *already* running
    returns the existing pid without re-running anything, so the previous
    version of this could not observe a launch at all once the app was up: it
    reported "nothing on the alerts channel" for an app that was logging
    `not scheduling` on every single launch, and blamed the missing permission
    prompt for it. Terminate first, attach, then launch.

    The banner `log stream` prints before its first record is what says the
    stream is attached. Waiting for it rather than sleeping a guessed interval
    is the difference between a race this can lose and one it cannot.
    """
    run("xcrun", "simctl", "terminate", udid, APP_BUNDLE_ID, check=False)

    command = (
        "xcrun", "simctl", "spawn", udid, "log", "stream",
        "--style", "ndjson", "--predicate", LOG_PREDICATE,
    )
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    process.stdout.readline()

    run("xcrun", "simctl", "launch", udid, APP_BUNDLE_ID)
    print(f"launched {APP_BUNDLE_ID}, listening for {seconds}s")

    lines: list[dict] = []
    try:
        process.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        process.terminate()
    output, _ = process.communicate()

    for line in (output or "").splitlines():
        try:
            entry = json.loads(line)
            lines.append(json.loads(entry["eventMessage"]))
        except (json.JSONDecodeError, KeyError, TypeError):
            # log stream emits a non-JSON banner line of its own before the
            # first record. Anything else unparseable is worth seeing raw.
            continue
    return lines


def report(entries: list[dict]) -> int:
    if not entries:
        print("\nNothing on the alerts channel.")
        print("\nThe app was relaunched with the stream already attached, so this is not a race:")
        print("it means `SessionAlertScheduler.reschedule` was never reached. Check that")
        print("`ContentView` still calls it from `.task`, and that the build on the device is")
        print("the one you just made.")
        return 1

    print()
    for entry in entries:
        detail = " ".join(f"{k}={v}" for k, v in entry.items() if k != "msg")
        print(f"  {entry.get('msg')}  {detail}".rstrip())

    scheduled = [e for e in entries if e.get("msg") == "rescheduled"]
    refused = [e for e in entries if e.get("msg") == "not scheduling"]

    if refused and not scheduled:
        print("\nThe app declined to schedule: iOS has not authorized notifications.")
        print("`authorization` is a UNAuthorizationStatus — 0 notDetermined, 1 denied, 2 authorized.")
        print("\n  0: nobody has been asked. Open the app, tap the ⓘ, then `Session alerts` —")
        print("     opening that screen with an alert switched on is what asks. Press Allow.")
        print("  1: iOS has been told no, and only Settings can undo it:")
        print("     Settings > Notifications > No Spoilers > Allow Notifications.")
        return 1

    if not scheduled:
        print("\nNo reschedule happened. The app ran but never reached the scheduler.")
        return 1

    last = scheduled[-1]
    planned, pending = last.get("planned"), last.get("pending")
    print(f"\n  planned {planned}, pending {pending}")
    if planned == 0:
        print("\nNothing to schedule. Either every alert is switched off, or the schedule holds")
        print("no session ahead of now that the preferences ask about.")
        return 0
    if planned != pending:
        print("\nThe OS is holding fewer than we asked for. 64 is the cap; above that it drops")
        print("the excess silently, which is what `limit` in SessionAlertPlanner exists to")
        print("prevent. This is a real finding.")
        return 1
    print("\nThe plan reached the OS intact.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__.split("\n")[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--device", default=DEFAULT_DEVICE,
                        help=f"simulator name or UDID (default {DEFAULT_DEVICE})")
    parser.add_argument("--install", type=Path,
                        help="path to a built NoSpoilersApp.app to install first")
    parser.add_argument("--push", choices=("start", "safe"),
                        help="deliver one notification with the real copy, and stop. "
                             "Renders the wording; does not test scheduling.")
    parser.add_argument("--watch", type=int, default=25, metavar="SECONDS",
                        help="how long to listen to the alerts channel (default 25)")
    arguments = parser.parse_args()

    udid = device_udid(arguments.device)
    print(f"device  {device_name(udid)}  {udid}")

    # Booted before installing, not after: `simctl install` on a shut-down device
    # fails with CoreSimulator 405. screenshots.py can install either way round
    # because it reboots afterwards regardless; this one needs the device up to
    # launch the app anyway.
    boot(udid)
    ensure_installed(udid, arguments.install)

    if arguments.push:
        push(udid, arguments.push)
        return 0

    return report(observe(udid, arguments.watch))


if __name__ == "__main__":
    raise SystemExit(main())

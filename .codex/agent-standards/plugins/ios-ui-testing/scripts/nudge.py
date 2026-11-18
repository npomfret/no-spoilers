#!/usr/bin/env python3
"""PostToolUse hook: send a session to the ios-ui-testing skill the first time it touches an iOS UI test.

browser-testing's nudge, for XCUITest, and for the same measured reason: a skill
description loads reliably when the request is plainly about the thing, and not
when the work reaches it partway through (2026-09-12, fantasy-football). A
request to fix a screen and "add a UI test for it" reaches the UI test target
only at the end, after the session has stopped thinking about which skills apply.

A Swift file is a UI test when it uses XCUIApplication or XCUIElement. That
covers tests and page objects alike, and it is read from the file rather than
guessed from its folder, because a page object need not live under *UITests/. A
test plan is a UI test file too: it is where retries and repetitions are set.

It says so once per context. A marker per session remembers that it spoke;
compaction drops the context, so SessionStart with source `compact` clears the
marker (`--forget`). It stays silent when the transcript already shows the skill
loaded.
"""
import json
import pathlib
import re
import sys
import tempfile

SKIPPED = {"Pods", "DerivedData", "build", "node_modules"}
DRIVER = re.compile(r"\bXCUI(Application|Element)\b")
LOADED = re.compile(r'"skill"\s*:\s*"(ios-ui-testing:)?ios-ui-testing"')

NUDGE = """\
You are working on an iOS UI test, and this project follows the iOS UI testing \
standard. If you have not loaded it in this session, load it now with the Skill \
tool (`ios-ui-testing:ios-ui-testing`) before writing or changing any UI test, \
page object or test plan. In short: tests never touch the screen - querying, \
tapping, typing, reading or asserting on an element happens only in a page \
object; elements are found the way a person finds them, narrowing from a title, \
label or text into its section, never by accessibility identifier or the query \
subscript, and each lookup matches exactly one element - never firstMatch or \
element(boundBy:); no change is instant, so every check polls with \
waitForExistence, waitForNonExistence or wait(for:toEqual:) and never sleeps; \
every page-object action waits for its own effect and returns the page object \
for where the user lands, so a test never launches the app or constructs one; \
never tap a coordinate or retry a side effect; page objects are full of sanity \
checks so a failure names its real cause; a flaky test is a failing test."""


def marker(event):
    key = event.get("session_id") or "unknown"
    if event.get("agent_id"):
        key += "-" + event["agent_id"]
    return pathlib.Path(tempfile.gettempdir()) / "ios-ui-testing" / key


def ui_test(path):
    path = pathlib.Path(path)
    if SKIPPED.intersection(path.parts):
        return False
    if path.suffix == ".xctestplan":
        return True
    if path.suffix != ".swift":
        return False
    try:
        return bool(DRIVER.search(path.read_text(errors="ignore")))
    except OSError:
        return False


def skill_loaded(transcript):
    try:
        with open(transcript, errors="ignore") as f:
            return any(LOADED.search(line) for line in f)
    except (OSError, TypeError):
        return False


def main():
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return
    spoken = marker(event)
    if "--forget" in sys.argv:
        spoken.unlink(missing_ok=True)
        return
    path = (event.get("tool_input") or {}).get("file_path")
    if not path or spoken.exists() or not ui_test(path):
        return
    spoken.parent.mkdir(parents=True, exist_ok=True)
    spoken.touch()
    if skill_loaded(event.get("transcript_path")):
        return
    print(json.dumps({
        "hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": NUDGE}
    }))


if __name__ == "__main__":
    main()

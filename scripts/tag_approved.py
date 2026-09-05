#!/usr/bin/env python3
"""Mark the commit users got: `PLATFORM/vX.Y.Z` on the build App Store Connect approved.

A version tag should point at what shipped, and until task 32 (2026-09-05)
none of this repository's did: `release.sh` wrote `vX.Y.Z` at the *first*
upload of a train, so `v1.1.2` marks build 10003 while the build on sale is
10012. Which build of a version reaches the store is decided by App Review,
after every upload, and only App Store Connect knows it — so this asks
(`appstore_status.approved_build`), finds the commit that build was archived
from (`testflight_distribute.ship_commit`: the `build/N` tag, or the `bump to`
commit for builds 10001–10022, which predate the tags), and writes an
annotated `ios/vX.Y.Z` or `macos/vX.Y.Z` there.

Two names rather than one bare `vX.Y.Z`, because the platforms are approved at
different builds — iOS 1.1.2 at 10012, macOS 1.1.2 not yet submitted — and one
tag cannot point at both. The bare name stays with the macOS Developer ID
release, whose Homebrew cask downloads by it.

`ci-publish-ios.sh` runs this for iOS the moment `--train` reports a version
closed, before it opens the next one; a person runs it for macOS. Idempotent:
a tag already on the right commit is reported and left alone. A tag on a
*different* commit is a contradiction and stops the run rather than being
moved — a tag that moves is a tag nobody can trust, and nothing here has the
standing to decide which of the two records is wrong.

Reads App Store Connect with the Developer key, like the report, and writes
only to git. Dry-run by default; `--apply` creates the tag and pushes it.

Usage:
    scripts/tag_approved.py ios 1.1.2            # what would happen
    scripts/tag_approved.py ios 1.1.2 --apply
    scripts/tag_approved.py --selftest
"""

from __future__ import annotations

import argparse
import sys

import appstore_status as asc
from testflight_distribute import git, ship_commit


def tag_name(platform: str, version: str) -> str:
    """`ios/v1.1.2`: the platform in its flag spelling, the version bare.

    The flag spelling and not Apple's, because `_version.sh` reads `ios/v*`
    and `macos/v*` by those literal names when it suggests the next version.
    """
    if platform not in asc.PLATFORM_FLAGS:
        raise SystemExit(
            f"unknown platform {platform!r} (expected one of {', '.join(sorted(asc.PLATFORM_FLAGS))})"
        )
    return f"{platform}/v{version}"


def decide(tag: str, existing: str | None, wanted: str) -> str:
    """What to do about the tag: `create`, `keep` (already right), or a hard stop."""
    if existing is None:
        return "create"
    if existing == wanted:
        return "keep"
    raise SystemExit(
        f"{tag} already marks {existing[:12]}, and App Store Connect says the approved build "
        f"was archived from {wanted[:12]}.\n"
        "One of the two records is wrong and this will not move a published tag to find out "
        "which. Look at both before touching either."
    )


def tag_target(tag: str) -> str | None:
    """The commit an existing tag marks — through the annotation — or None."""
    if not git("tag", "-l", tag).strip():
        return None
    return git("rev-list", "-n1", tag).strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("platform", choices=sorted(asc.PLATFORM_FLAGS))
    parser.add_argument("version", help="the marketing version, e.g. 1.1.2")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="create the tag and push it to origin; without it, say what would happen",
    )
    arguments = parser.parse_args([a for a in sys.argv[1:] if a != "--selftest"])

    tag = tag_name(arguments.platform, arguments.version)
    client = asc.Client()
    app_id = asc.find_app(client.get)["id"]
    number = asc.approved_build(
        client.get, app_id, asc.PLATFORM_FLAGS[arguments.platform], arguments.version
    )
    if number is None:
        raise SystemExit(
            f"{arguments.platform} {arguments.version} has not reached the store, so there is "
            "nothing to mark yet"
        )
    print(f"{arguments.platform} {arguments.version} is on the store as build {number}")

    # The build/ tag was pushed by whichever machine shipped, and this one may
    # not have seen it; a stale answer here is "nothing records build N".
    git("fetch", "--quiet", "--tags", "origin")
    commit = ship_commit(number)
    if commit is None:
        raise SystemExit(
            f"nothing in this repository records which commit build {number} was archived "
            f"from: no build/{number} tag and no `bump to` commit.\n"
            "Every release.sh upload leaves one or the other, so either this is an Xcode Cloud "
            "build — whose commit is its run's sourceCommit, not anything in git — or the "
            "record is incomplete. Neither is something to tag over."
        )
    print(f"build {number} was archived from {commit['sha'][:12]} {commit['subject']} ({commit['source']})")

    action = decide(tag, tag_target(tag), commit["sha"])
    if action == "keep":
        print(f"{tag} already marks it. Nothing to do.")
        return 0
    if not arguments.apply:
        print(f"would tag {tag} there and push it. Re-run with --apply.")
        return 0

    git(
        "tag", "-a", tag, commit["sha"],
        "-m", f"{tag}: build {number}, on the store",
        "-m", f"The build of {arguments.version} App Store Connect reports as approved for "
        f"{arguments.platform}, on the commit it was archived from.",
    )
    git("push", "--quiet", "origin", tag)
    print(f"tagged {tag} and pushed it.")
    return 0


def _selftest() -> int:
    """Offline. The naming and the one decision; the git and the API are not exercised."""
    failures: list[str] = []

    # `_version.sh` reads `ios/v*` and `macos/v*` by those literal names, so
    # the platforms this can tag and the names it gives them are pinned to
    # what that script expects. A third platform, or Apple's spelling, would
    # write a tag `suggest_next_version` never reads.
    if sorted(asc.PLATFORM_FLAGS) != ["ios", "macos"]:
        failures.append(f"the platforms are {sorted(asc.PLATFORM_FLAGS)}; _version.sh reads ios/ and macos/")
    if tag_name("ios", "1.1.2") != "ios/v1.1.2":
        failures.append(f"tag_name spelled iOS as {tag_name('ios', '1.1.2')!r}")
    if tag_name("macos", "1.1.2") != "macos/v1.1.2":
        failures.append(f"tag_name spelled macOS as {tag_name('macos', '1.1.2')!r}")
    try:
        tag_name("MAC_OS", "1.1.2")
        failures.append("tag_name accepted Apple's platform spelling")
    except SystemExit:
        pass

    SHA = "0123456789abcdef0123456789abcdef01234567"
    OTHER = "89abcdef0123456789abcdef0123456789abcdef"
    if decide("ios/v1.1.2", None, SHA) != "create":
        failures.append("decide did not create a tag that does not exist")
    if decide("ios/v1.1.2", SHA, SHA) != "keep":
        failures.append("decide did not keep a tag already on the right commit")
    # The one hard stop. Moving it would make the tag agree with today's
    # answer and say nothing about why yesterday's differed.
    try:
        decide("ios/v1.1.2", OTHER, SHA)
        failures.append("decide moved a tag that marks a different commit")
    except SystemExit:
        pass

    for failure in failures:
        print(f"  FAIL {failure}", file=sys.stderr)
    print(f"tag_approved selftest: 7 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    sys.exit(main())

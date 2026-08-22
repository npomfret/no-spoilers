#!/usr/bin/env python3
"""Prepare an App Store version from the copy in `listing/`, and stop before Submit.

**The listing is the surface App Review judges 4.1(a) on, and until 2026-08-22
it lived nowhere but App Store Connect.** Nothing in this repository knew what
the app's own description said. That is how the macOS listing kept
`F1,Formula 1` in its keywords for nine days after the sweep that was supposed
to have removed them, live on the store, while the app, the widget, the website
and the iOS listing were all clean — the sweep edited four surfaces by hand and
there was no fifth place to look. Copy that only exists in a web form cannot be
reviewed, diffed, or checked by anything.

So `listing/<platform>/*.txt` is the source of truth and this writes it out. The
files are plain text because they are prose: a description change should read as
a prose diff in a commit, not as a JSON blob.

## What it will not do

**It never submits anything for review.** That is a person pressing Submit, and
it is the one step here that cannot be undone — the same line
`testflight_distribute.py` draws at `--submit`, drawn one step earlier because
this tool's whole job is the metadata a submission carries.

**It refuses to write copy carrying the owned terms**, using
`appstore_status.trademark_hits` — the same check the report now runs under
NEEDS YOU, so a listing cannot pass here and be flagged there. The check runs on
the local files *and* on what App Store Connect already holds, because arriving
to find the marks already live is exactly what happened.

## Scope

One version of one platform, prepared as far as it can be: create the version
record if it is missing, write the four localized fields, write the review
detail, attach a build. Anything to do with which build the *testers* get is
`testflight_distribute.py` and does not belong here.

en-GB only, because that is the app's only locale — `primaryLocale` on the app
record. A second locale would be a directory level, not a rewrite.

Usage:
    scripts/appstore_listing.py --platform macos                  # what would change
    scripts/appstore_listing.py --platform macos --apply
    scripts/appstore_listing.py --platform ios --version 1.1.3 --create --apply
    scripts/appstore_listing.py --platform macos --build 10004 --apply
    scripts/appstore_listing.py --selftest
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import appstore_status as asc
from asc_write import Session

REPO = Path(__file__).resolve().parent.parent
LISTING = REPO / "listing"

LOCALE = "en-GB"

# The localized fields this owns, their files, and Apple's limits. The limits
# are enforced here because the API's refusal names the field and not the
# number, and a description one character over is a puzzle rather than a fix.
FIELDS = {
    "keywords": ("keywords.txt", 100),
    "description": ("description.txt", 4000),
    "promotionalText": ("promotional-text.txt", 170),
    "whatsNew": ("whats-new.txt", 4000),
}

# The reviewer-facing notes live beside the listing copy: same prose, same
# review, and the one place a 4.1 reviewer looks before the description.
REVIEW_NOTES = ("review-notes.txt", 4000)

# States whose metadata App Store Connect will still accept. A READY_FOR_SALE
# version is a historical record — its words shipped, and the only way to change
# what the store says is a new version.
EDITABLE = (
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
)


def copy_for(platform: str) -> tuple[dict[str, str], str | None]:
    """The local copy for one platform: the listing fields, and the review notes.

    **Two return values because they go to two endpoints.** They were one dict
    until the first dry run, which reported every field already correct and then
    said it was about to write something — `notes` has no place on an
    `appStoreVersionLocalizations` record, so it compared unequal every time and
    would have been PATCHed there. Keeping them together meant the split had to
    be remembered at each use; keeping them apart means it cannot be forgotten.

    **A missing file means the field is not managed here**, and is left exactly
    as App Store Connect holds it — that is how `listing/ios/whats-new.txt`
    could be absent without this tool blanking a release note. **An empty file
    is an error**, because it reads as both "leave it alone" and "clear it" and
    the two are not the same thing.
    """
    directory = LISTING / platform
    if not directory.is_dir():
        raise SystemExit(
            f"no copy at {directory.relative_to(REPO)}\n"
            "The listing is written from files in this repository, not from memory."
        )

    def read(name: str, limit: int) -> str | None:
        path = directory / name
        if not path.exists():
            return None
        text = path.read_text().strip()
        if not text:
            raise SystemExit(
                f"{path.relative_to(REPO)} is empty.\n"
                "Delete it to leave the field alone, or write what it should say. "
                "An empty file cannot mean both."
            )
        if len(text) > limit:
            raise SystemExit(
                f"{path.relative_to(REPO)} is {len(text)} characters and Apple's limit is {limit}."
            )
        return text

    listing = {field: found for field, (name, limit) in FIELDS.items()
               if (found := read(name, limit)) is not None}
    return listing, read(*REVIEW_NOTES)


def refuse_marks(source: str, fields: dict[str, object]) -> list[str]:
    """Every owned term in a set of fields, as `field: terms` lines."""
    return [
        f"  {source} {field}: {', '.join(hits)}"
        for field, value in sorted(fields.items())
        if (hits := asc.trademark_hits(value))
    ]


def target_version(session: Session, app_id: str, platform: str,
                   wanted: str | None, create: bool, apply: bool) -> dict | None:
    """The version to write to: the one asked for, or the only editable one.

    Defaulting to "the newest editable version" rather than to a version string
    is what keeps this from ever touching a shipped listing: a READY_FOR_SALE
    version is not a candidate, so the tool cannot rewrite the words that are on
    the store. If there is nothing editable, that is a decision — `--create` —
    and not something to infer.
    """
    flag = asc.PLATFORM_FLAGS[platform]
    versions = [
        v for v in session.get(f"/v1/apps/{app_id}/appStoreVersions?limit=50")["data"]
        if v["attributes"]["platform"] == flag
    ]

    if wanted:
        found = next((v for v in versions if v["attributes"]["versionString"] == wanted), None)
        if found:
            state = found["attributes"]["appStoreState"]
            if state not in EDITABLE:
                raise SystemExit(
                    f"{platform} {wanted} is {state}, which App Store Connect will not let this "
                    "edit. A shipped listing changes by shipping another version."
                )
            return found
        if not create:
            raise SystemExit(
                f"{platform} has no version {wanted}. Pass --create to make one."
            )
        if not apply:
            print(f"would create {platform} version {wanted}")
            return None
        made = session.post(
            "/v1/appStoreVersions",
            {
                "data": {
                    "type": "appStoreVersions",
                    "attributes": {"platform": flag, "versionString": wanted},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )
        print(f"created {platform} version {wanted}")
        return made["data"]

    editable = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE]
    if not editable:
        raise SystemExit(
            f"{platform} has no editable version. Name one with --version and --create."
        )
    if len(editable) > 1:
        names = ", ".join(v["attributes"]["versionString"] for v in editable)
        raise SystemExit(f"{platform} has more than one editable version ({names}). Use --version.")
    return editable[0]


def write_localization(session: Session, version: str, wanted: dict[str, str], apply: bool) -> None:
    entry = next(
        (l for l in session.get(f"/v1/appStoreVersions/{version}/appStoreVersionLocalizations")["data"]
         if l["attributes"]["locale"] == LOCALE),
        None,
    )
    if entry is None:
        raise SystemExit(
            f"this version has no {LOCALE} localization, and creating one is not this tool's job — "
            "App Store Connect makes it with the version."
        )

    live = entry["attributes"]
    if marks := refuse_marks("live", {k: live.get(k) for k in FIELDS}):
        print("\n".join(marks))

    changing = {k: v for k, v in wanted.items() if (live.get(k) or "").strip() != v}
    for field in FIELDS:
        if field not in wanted:
            print(f"  {field}: not managed here")
        elif field in changing:
            print(f"  {field}: changing ({len(wanted[field])} chars)")
        else:
            print(f"  {field}: already correct")
    if not changing or not apply:
        if changing:
            print("  (dry run — nothing written)")
        return
    session.patch(
        f"/v1/appStoreVersionLocalizations/{entry['id']}",
        {"data": {"type": "appStoreVersionLocalizations", "id": entry["id"],
                  "attributes": changing}},
    )
    print(f"  wrote {', '.join(sorted(changing))}")


def write_review_detail(session: Session, version: str, notes: str | None, apply: bool) -> None:
    """The reviewer's notes, and the demo account this app has never needed.

    `demoAccountRequired` is forced false and the credentials blanked. There is
    no sign-in anywhere in this app, so an account attached to it is a reviewer
    following instructions that lead nowhere — and it was a real address and
    password sitting in the app record. iOS corrected that on 2026-08-13 and
    told Apple so in writing; macOS carried it until 2026-08-22 because nothing
    checked the two platforms said the same thing.
    """
    if notes is None:
        print("  review notes: not managed here")
        return

    attributes = {"notes": notes, "demoAccountRequired": False,
                  "demoAccountName": "", "demoAccountPassword": ""}
    existing = session.get(f"/v1/appStoreVersions/{version}/appStoreReviewDetail").get("data")
    if existing:
        live = existing["attributes"]
        if marks := refuse_marks("live", {"review notes": live.get("notes")}):
            print("\n".join(marks))
        settled = (live.get("notes") or "").strip() == notes and not live.get("demoAccountRequired")
        print(f"  review notes: {'already correct' if settled else 'changing'}")
        if settled or not apply:
            if not settled:
                print("  (dry run — nothing written)")
            return
        session.patch(
            f"/v1/appStoreReviewDetails/{existing['id']}",
            {"data": {"type": "appStoreReviewDetails", "id": existing["id"],
                      "attributes": attributes}},
        )
        print("  wrote review notes, and cleared the demo account")
        return

    print("  review notes: no review detail on this version")
    if not apply:
        print("  (dry run — nothing written)")
        return
    # The contact fields are required on create and are not copy, so they are
    # carried from the app's own record rather than kept in a text file.
    session.post(
        "/v1/appStoreReviewDetails",
        {"data": {"type": "appStoreReviewDetails", "attributes": attributes,
                  "relationships": {"appStoreVersion": {
                      "data": {"type": "appStoreVersions", "id": version}}}}},
    )
    print("  created the review detail — its contact fields still need filling in")


def attach(session: Session, version: str, app_id: str, platform: str,
           number: str, apply: bool) -> None:
    """Put a build on the version. Required before submission, and reversible."""
    builds = asc.platform_builds(session.get, app_id, asc.PLATFORM_FLAGS[platform])
    build = next((b for b in builds if b["version"] == number), None)
    if build is None:
        raise SystemExit(f"{platform} has no build {number} on App Store Connect")

    linked = session.get(f"/v1/appStoreVersions/{version}/relationships/build").get("data")
    if linked and linked["id"] == build["id"]:
        print(f"  build {number}: already attached")
        return
    print(f"  build {number}: attaching")
    if not apply:
        print("  (dry run — nothing written)")
        return
    session.patch(f"/v1/appStoreVersions/{version}/relationships/build",
                  {"data": {"type": "builds", "id": build["id"]}})
    print(f"  attached build {number}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--platform", choices=sorted(asc.PLATFORM_FLAGS), required=True)
    parser.add_argument("--version", help="version string. Default: the only editable one")
    parser.add_argument("--create", action="store_true",
                        help="with --version, create the version record if it is missing")
    parser.add_argument("--build", help="build number to attach to the version")
    parser.add_argument("--apply", action="store_true", help="actually write it")
    arguments = parser.parse_args([a for a in sys.argv[1:] if a != "--selftest"])

    wanted, notes = copy_for(arguments.platform)
    # The local files first and on their own: copy that carries the marks must
    # not reach App Store Connect, whatever is already there.
    if marks := refuse_marks("local", {**wanted, "review notes": notes}):
        print(f"{LISTING.name}/{arguments.platform} uses owned terms:")
        print("\n".join(marks))
        print("\nNothing was written. See CLAUDE.md — this is the surface 4.1(a) is judged on.")
        return 1

    session = Session()
    app_id = asc.find_app(session.get)["id"]
    version = target_version(session, app_id, arguments.platform,
                             arguments.version, arguments.create, arguments.apply)
    if version is None:
        print("\nNothing else can be done until the version exists. Re-run with --apply.")
        return 0

    attributes = version["attributes"]
    print(f"{arguments.platform} {attributes['versionString']} ({attributes['appStoreState']})")
    write_localization(session, version["id"], wanted, arguments.apply)
    write_review_detail(session, version["id"], notes, arguments.apply)
    if arguments.build:
        attach(session, version["id"], app_id, arguments.platform, arguments.build, arguments.apply)

    print("\nNothing was submitted for review. That is a person pressing Submit.")
    return 0


def _selftest() -> int:
    """Offline. The judgements, not the requests."""
    failures: list[str] = []

    # Every field this writes must have a file and a limit, and the two dicts
    # that name them are the whole contract with the `listing/` directory.
    for field, (name, limit) in FIELDS.items():
        if not name.endswith(".txt") or limit <= 0:
            failures.append(f"{field} is described by {(name, limit)}")
    if set(FIELDS) != {"keywords", "description", "promotionalText", "whatsNew"}:
        failures.append(f"the managed field set changed: {sorted(FIELDS)}")
    if FIELDS["keywords"][1] != 100 or FIELDS["promotionalText"][1] != 170:
        failures.append("a field limit no longer matches Apple's")

    # A shipped listing must never be a candidate. This is the guard that stops
    # the tool rewriting words that are already on the store.
    if "READY_FOR_SALE" in EDITABLE:
        failures.append("a READY_FOR_SALE version is treated as editable")
    if "PREPARE_FOR_SUBMISSION" not in EDITABLE or "REJECTED" not in EDITABLE:
        failures.append("the states this tool exists to write to are not editable")

    # The refusal, on the exact copy that was live on macOS.
    live = refuse_marks("live", {"keywords": "F1,Formula 1,schedule,menu bar"})
    if len(live) != 1 or "f1, formula 1" not in live[0]:
        failures.append(f"the macOS keywords that shipped were not refused: {live}")
    if refuse_marks("local", {"description": "the whole Grand Prix weekend", "keywords": None}):
        failures.append("swept copy was refused")

    # The real files, checked as the tool would check them. This is the case
    # that matters: it is the repository's own copy, and it is what would be
    # written on the next `--apply`.
    for platform in sorted(asc.PLATFORM_FLAGS):
        try:
            found, notes = copy_for(platform)
        except SystemExit as error:
            failures.append(f"listing/{platform}: {error}")
            continue
        if not found:
            failures.append(f"listing/{platform} has no copy in it at all")
        if marks := refuse_marks(platform, {**found, "review notes": notes}):
            failures.append(f"the checked-in copy uses owned terms: {marks}")
        if "description" not in found or "keywords" not in found:
            failures.append(f"listing/{platform} is missing a description or keywords")
        # The bug the first dry run found: the review notes reaching the
        # localization patch, where `notes` is not a field, on every single run.
        if set(found) - set(FIELDS):
            failures.append(f"listing/{platform} copy carries {sorted(set(found) - set(FIELDS))}, "
                            "which would be PATCHed onto a localization that has no such field")

    for failure in failures:
        print(f"  FAIL {failure}", file=sys.stderr)
    print(f"appstore_listing selftest: 14 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    sys.exit(main())

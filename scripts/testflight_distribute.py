#!/usr/bin/env python3
"""Put the newest iOS build in front of the testers, deliberately.

**An Xcode Cloud build arrives attached to no tester group at all**, and until
it is put in one, nobody can install it. This is true of the internal group as
much as an external one. `hasAccessToAllBuilds` decides which builds a tester
*may* see, not which builds exist for them, and a group created with that flag
still receives nothing on its own.

Nothing reports the gap, and every signal reads as success: the Xcode Cloud run
is green, the build is VALID, `internalBuildState` is READY_FOR_BETA_TESTING,
and the group's own build list is empty either way so it distinguishes nothing.
The question that answers honestly is `GET /v1/builds/{id}?include=betaGroups` —
an empty `included` means no tester will ever see it.

Adding the build sends any pending invitation by itself. External groups need
one further step: the first build of each marketing version waits on Beta App
Review, which `--submit` starts.

**Newest means most recently uploaded, never the highest build number.** Two
upload paths feed this one app record and their numbers are deliberately kept
apart: `scripts/release.sh` starts at 10000 and counts up, Xcode Cloud uses its
run number. So a fresh CI build is `5` while last month's manual upload is
`10001`, and picking the larger number would hand testers the older build for as
long as both paths stay in use. See tasks/14-xcode-cloud-testflight.md, Phase 0
Decision 1.

**One App Store record covers macOS and iOS**, so an unfiltered build list mixes
the two and the newest upload is as likely to be a Mac build. Every query here
is filtered to `PLATFORM`.

**It also repairs the *What to Test* note**, because Apple's own pickup of it
cannot be relied on. `NoSpoilers/ci_scripts/ci_post_clone.sh` writes the note
into the checkout on every run and App Store Connect reads it on some runs and
not others: builds 3 and 9 carried their own note, builds 4, 5 and 6 all carried
build 3's. Every one of those runs logged the file written correctly, the log
bundles are indistinguishable, and no artifact Apple exposes records whether the
file was read. So this script stops depending on it — it asks the Xcode Cloud
run for the commit and writes `whatsNew` over the API, where the result is
visible and the failure is an HTTP error rather than silence.

A stale note is worse than no note: it describes changes the tester does not
have, and it looks entirely plausible while doing it. The check is therefore not
"is there a note" but "does the note name *this* build".

This is the only Python file here that writes to App Store Connect.
`appstore_status.py` stays a report and issues `GET`s alone; keeping the two
apart is what makes it safe to run the report whenever the answer is in doubt.
It is also why they hold different keys.

It refuses to act without `--apply`, and it will not submit anything for review
unless asked twice: adding a build to a group can be undone, and a review
submission cannot.

Internal groups only, unless `--group` names one. The public link is never fed
by accident.

Usage:
    scripts/testflight_distribute.py                          # what would happen
    scripts/testflight_distribute.py --apply
    scripts/testflight_distribute.py --group Friends --apply --submit
    scripts/testflight_distribute.py --selftest
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request

import appstore_status as asc

# An App Manager key. The Developer-level key `appstore_status.py` uses reads
# every one of these endpoints and is then refused the write with an empty 403,
# which is the least helpful error in this API — see `_hint`.
ADMIN_KEY_ID = "ASC6H3SL2D"

# Task 14 is the iOS delivery path. The Mac app ships Developer ID and Homebrew
# through `scripts/release.sh` and has no TestFlight story here, so a build of it
# turning up in this script's candidates would only ever be a mistake.
PLATFORM = "IOS"

# The Xcode Cloud product, hard-coded because it cannot be discovered reliably:
# `GET /v1/ciProducts` has been observed answering `total: 0` on this team while
# individual products still resolved by id, which is what made Xcode refuse to
# create the workflow. Fetching by id is the path that has never failed. Recorded
# in tasks/14-xcode-cloud-testflight.md under "Live configuration".
CI_PRODUCT_ID = "1F3A0BBD-DC5B-44FA-A767-65B3E14A433B"

# Matches the file `ci_post_clone.sh` writes: WhatToTest.en-GB.txt.
NOTE_LOCALE = "en-GB"

# What each build state means for the question being asked here: can this build
# reach this kind of tester, and what stands in the way. The states are Apple's;
# the flag is whether adding it to a group is worth trying.
INTERNAL_STATES = {
    "PROCESSING": ("still processing at Apple; try again in a few minutes", False),
    "PROCESSING_EXCEPTION": ("processing failed at Apple; this build is dead", False),
    "MISSING_EXPORT_COMPLIANCE": (
        "waiting on the encryption question — ITSAppUsesNonExemptEncryption should "
        "have answered it at build time",
        False,
    ),
    "READY_FOR_BETA_TESTING": ("ready for the team, and needs no review", True),
    "IN_BETA_TESTING": ("already out with the team", True),
    "EXPIRED": ("expired — TestFlight builds last 90 days", False),
}

EXTERNAL_STATES = {
    "NOT_APPLICABLE": (
        "archived INTERNAL_ONLY, so it can never go outside the team — "
        "no setting fixes it, only a new build from an APP_STORE_ELIGIBLE archive",
        False,
    ),
    "PROCESSING": ("still processing at Apple; try again in a few minutes", False),
    "PROCESSING_EXCEPTION": ("processing failed at Apple; this build is dead", False),
    "MISSING_EXPORT_COMPLIANCE": (
        "waiting on the encryption question — ITSAppUsesNonExemptEncryption should "
        "have answered it at build time",
        False,
    ),
    "READY_FOR_BETA_SUBMISSION": ("ready, and will need Beta App Review", True),
    "WAITING_FOR_BETA_REVIEW": ("already queued for Beta App Review", False),
    "IN_BETA_REVIEW": ("in Beta App Review now", False),
    "BETA_REJECTED": ("rejected by Beta App Review; read Resolution Center", False),
    "READY_FOR_BETA_TESTING": ("approved, and can be handed to a group", True),
    "IN_BETA_TESTING": ("already out with external testers", True),
    "EXPIRED": ("expired — TestFlight builds last 90 days", False),
}


def builds_path(app_id: str) -> str:
    """Every build of this app on one platform.

    The platform filter is not a convenience. Without it this returns the Mac
    app's builds too, interleaved by date, and the newest upload is then as
    likely to be a Mac build that has no business in an iOS tester group.
    """
    return f"/v1/builds?filter[app]={app_id}&filter[preReleaseVersion.platform]={PLATFORM}&limit=200"


class Session:
    """Signs with `appstore_status`'s token, and writes, which it does not."""

    def __init__(self) -> None:
        key = asc.key_path(ADMIN_KEY_ID)
        if not key.exists():
            raise SystemExit(
                f"no private key at {key}\n"
                f"{ADMIN_KEY_ID} must be an App Manager key, downloadable once from "
                "App Store Connect > Users and Access > Integrations. The Developer key "
                "the rest of this repo uses cannot distribute a build."
            )
        self.bearer = asc.token(asc.ISSUER_ID, ADMIN_KEY_ID, key)

    def _call(self, method: str, path: str, body: dict | None = None) -> dict:
        request = urllib.request.Request(
            asc.API + path,
            data=json.dumps(body).encode() if body is not None else None,
            method=method,
            headers={
                "Authorization": f"Bearer {self.bearer}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=asc.TIMEOUT) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:400]
            raise SystemExit(f"{method} {path} -> HTTP {error.code}\n{detail}{_hint(error.code)}")

    def get(self, path: str) -> dict:
        return self._call("GET", path)

    def post(self, path: str, body: dict) -> dict:
        return self._call("POST", path, body)

    def patch(self, path: str, body: dict) -> dict:
        return self._call("PATCH", path, body)


def _hint(code: int) -> str:
    """The two failures worth naming, because neither says what it means.

    A 403 from this API arrives with an empty `detail` and is indistinguishable
    from a malformed body, which sends you rewriting a request that was fine.
    """
    if code == 403:
        return (
            "\n\nA 403 here is almost always the key rather than the request: an App "
            "Store Connect key at Developer level reads all of this and is refused "
            f"every write. {ADMIN_KEY_ID} must still be an App Manager key."
        )
    if code == 401:
        return "\n\nA 401 means the .p8 is not an App Store Connect key, or the issuer is wrong."
    return ""


def newest_build(builds: list[dict]) -> dict | None:
    """The most recently uploaded build worth talking about.

    By upload date, never by build number — the two upload paths into this app
    use deliberately separate number bands, so the larger number is routinely
    the older build. See the module docstring.

    An expired build is not a candidate at any age: it will not install, and
    picking it would hide the newest one that still would.
    """
    live = [b for b in builds if not b["expired"]]
    if not live:
        return None
    return max(live, key=lambda b: b["uploaded"])


def explain(is_internal: bool, detail: dict) -> tuple[str, str, bool]:
    """What this build's state means for this kind of group.

    A build carries both states at once and they disagree constantly: an
    INTERNAL_ONLY archive is READY_FOR_BETA_TESTING internally and
    NOT_APPLICABLE externally. Reading the wrong one is how a build looks
    undeliverable when it is fine, or fine when it can never leave the team.
    """
    states = INTERNAL_STATES if is_internal else EXTERNAL_STATES
    state = detail["internalBuildState" if is_internal else "externalBuildState"]
    reason, actionable = states.get(
        state, (f"in state {state}, which this script has not seen", False)
    )
    return state, reason, actionable


def note_text(subject: str, sha: str, version: str) -> str:
    """The tester note for a build, in `ci_post_clone.sh`'s format.

    Deliberately byte-for-byte what the hook writes. The two are separate
    implementations of one format, which is a cost — but the alternative is a
    note that changes shape depending on which mechanism happened to win, and
    the whole problem here is not being able to tell them apart.
    """
    return f"{subject}\n\nBuild {version} from {sha[:12]}\n"


def note_names_build(whats_new: str | None, version: str) -> bool:
    """Whether this note is about this build, rather than merely present.

    The failure this exists for produces a note that is real, well-formed, and
    about a different build. `from ` is load-bearing: without it, build 1's
    marker matches build 10's note.
    """
    return bool(whats_new) and f"Build {version} from " in whats_new


def note_claims(whats_new: str | None) -> str | None:
    """The `Build N from <sha>` line a note carries, if it carries one.

    This is the only part of a note that identifies it. Two builds off the same
    branch routinely share a subject — `task update` and `task update` — so
    reporting the subject alone prints the same string twice and says nothing.
    """
    if not whats_new:
        return None
    for line in whats_new.strip().split("\n"):
        if line.startswith("Build ") and " from " in line:
            return line.strip()
    return None


def source_commit(session: Session, version: str) -> dict | None:
    """The commit that produced this build, or None if Xcode Cloud did not.

    A build's version *is* its run number: Xcode Cloud rewrites CFBundleVersion
    to CI_BUILD_NUMBER when it exports the IPA, so the two cannot disagree. See
    tasks/14-xcode-cloud-testflight.md, Phase 0 Decision 1.

    None is a valid answer, not a swallowed error. `release.sh` uploads from
    10000 up and no run produced them, and a run started from Xcode by hand can
    carry no source commit at all. Neither has a commit to name, and inventing
    one would be worse than leaving the note alone.

    `sort=-number` is required here — this endpoint answers oldest-first without
    it, so the newest runs fall off the end of the page.
    """
    if not version.isdigit():
        return None
    runs = session.get(f"/v1/ciProducts/{CI_PRODUCT_ID}/buildRuns?limit=200&sort=-number")["data"]
    run = next((r for r in runs if r["attributes"]["number"] == int(version)), None)
    if run is None:
        return None
    commit = run["attributes"].get("sourceCommit")
    if not commit:
        return None
    return {"subject": commit["message"].split("\n")[0], "sha": commit["commitSha"]}


def note_on(session: Session, build_id: str) -> dict | None:
    """This build's en-GB tester note, if it has one at all."""
    for localization in session.get(f"/v1/builds/{build_id}/betaBuildLocalizations")["data"]:
        if localization["attributes"]["locale"] == NOTE_LOCALE:
            return {
                "id": localization["id"],
                "whatsNew": localization["attributes"].get("whatsNew"),
            }
    return None


def write_note(session: Session, build_id: str, existing: dict | None, text: str) -> None:
    """Set the note, creating the localization if Apple never made one."""
    if existing is None:
        session.post(
            "/v1/betaBuildLocalizations",
            {
                "data": {
                    "type": "betaBuildLocalizations",
                    "attributes": {"locale": NOTE_LOCALE, "whatsNew": text},
                    "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
                }
            },
        )
        return
    session.patch(
        f"/v1/betaBuildLocalizations/{existing['id']}",
        {
            "data": {
                "type": "betaBuildLocalizations",
                "id": existing["id"],
                "attributes": {"whatsNew": text},
            }
        },
    )


def repair_note(session: Session, build: dict, apply: bool) -> None:
    """Make the note describe this build, or say why it cannot."""
    existing = note_on(session, build["id"])
    current = existing["whatsNew"] if existing else None
    if note_names_build(current, build["version"]):
        print("what to test: names this build already")
        return

    claim = note_claims(current)
    seen = f"claims {claim!r}" if claim else ("has no build marker" if current else "is missing")
    commit = source_commit(session, build["version"])
    if commit is None:
        print(f"what to test: {seen}, and no Xcode Cloud run produced this build, so leaving it")
        return

    wanted = note_text(commit["subject"], commit["sha"], build["version"])
    marker = note_claims(wanted)
    if not apply:
        print(f"what to test: {seen}. Would set {marker!r}. Re-run with --apply.")
        return
    write_note(session, build["id"], existing, wanted)
    print(f"what to test: {seen}, now {marker!r}")


def groups_holding(session: Session, build_id: str) -> set[str]:
    """Which groups this build is actually in.

    `GET /v1/betaGroups/{id}/builds` answers an empty list for an internal group
    whether or not the build is in it, so it cannot be used for this.
    """
    response = session.get(f"/v1/builds/{build_id}?include=betaGroups")
    return {g["id"] for g in response.get("included", [])}


def testers(session: Session, group_id: str) -> list[dict]:
    return [
        {"email": t["attributes"]["email"], "state": t["attributes"]["state"]}
        for t in session.get(f"/v1/betaGroups/{group_id}/betaTesters?limit=200")["data"]
    ]


def gather(session: Session, only: str | None) -> dict:
    app_id = asc.find_app(session.get)["id"]

    groups = session.get(f"/v1/apps/{app_id}/betaGroups?limit=50")["data"]
    if only is not None:
        groups = [g for g in groups if g["attributes"]["name"] == only]
        if not groups:
            raise SystemExit(f"no tester group named {only!r}")
    else:
        # Internal only unless a group is named. Sweeping up every group would
        # push each build at the public link, and an external release is a
        # decision somebody makes rather than a default that happens.
        groups = [g for g in groups if g["attributes"]["isInternalGroup"]]
    if not groups:
        raise SystemExit("this app has no tester groups, so there is nobody to deliver to")

    builds = [
        {
            "id": b["id"],
            "version": b["attributes"]["version"],
            "expired": b["attributes"]["expired"],
            "uploaded": b["attributes"]["uploadedDate"],
        }
        for b in session.get(builds_path(app_id))["data"]
    ]
    target = newest_build(builds)
    if target is None:
        raise SystemExit(f"no unexpired {PLATFORM} builds on App Store Connect at all")

    detail = session.get(f"/v1/builds/{target['id']}/buildBetaDetail")["data"]["attributes"]
    holding = groups_holding(session, target["id"])

    plans = []
    for group in groups:
        is_internal = group["attributes"]["isInternalGroup"]
        state, reason, actionable = explain(is_internal, detail)
        plans.append(
            {
                "id": group["id"],
                "name": group["attributes"]["name"],
                "internal": is_internal,
                "state": state,
                "reason": reason,
                "actionable": actionable,
                "present": group["id"] in holding,
                "testers": testers(session, group["id"]),
            }
        )
    return {"build": target, "plans": plans}


def deliver(session: Session, build: dict, plan: dict, submit: bool) -> None:
    session.post(
        f"/v1/betaGroups/{plan['id']}/relationships/builds",
        {"data": [{"type": "builds", "id": build["id"]}]},
    )
    print(f"  added build {build['version']} to {plan['name']}")

    pending = [t for t in plan["testers"] if t["state"] == "NOT_INVITED"]
    if pending:
        # Apple sends these itself now the group has something installable, so
        # this reports rather than acts. Chasing it with betaTesterInvitations
        # before the build was there is what returns NO_INSTALLABLE_BUILDS.
        print(f"  invitations now sending to {len(pending)} tester(s) who had none")

    if plan["internal"]:
        return

    after = session.get(f"/v1/builds/{build['id']}/buildBetaDetail")["data"]["attributes"]
    print(f"  external state is now {after['externalBuildState']}")
    if after["externalBuildState"] != "READY_FOR_BETA_SUBMISSION":
        return
    if not submit:
        print(
            "  it still needs Beta App Review, which the group add did not trigger.\n"
            "  re-run with --apply --submit to send it. That cannot be undone."
        )
        return

    session.post(
        "/v1/betaAppReviewSubmissions",
        {
            "data": {
                "type": "betaAppReviewSubmissions",
                "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}},
            }
        },
    )
    print("  submitted for Beta App Review — days rather than hours, historically")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--apply", action="store_true", help="actually add the build to the groups")
    parser.add_argument(
        "--submit",
        action="store_true",
        help="with --apply, also submit it for Beta App Review (not reversible)",
    )
    parser.add_argument(
        "--group",
        help="one group by name. Without it, only internal groups are touched — "
        "reaching the public link is always something you ask for by name.",
    )
    arguments = parser.parse_args([a for a in sys.argv[1:] if a != "--selftest"])

    session = Session()
    state = gather(session, arguments.group)
    build = state["build"]
    print(f"newest {PLATFORM} build {build['version']}, uploaded {build['uploaded'][:16]}")

    # The note belongs to the build, not to any group, so it is settled once
    # here rather than per group. It is also worth repairing on a build that is
    # already distributed: the testers have it, and what they were told about it
    # may still be describing somebody else's commit.
    repair_note(session, build, arguments.apply)
    print()

    blocked = 0
    for plan in state["plans"]:
        kind = "internal" if plan["internal"] else "external"
        print(f"{plan['name']} ({kind}) — {plan['state']}: {plan['reason']}")

        # An empty group takes the build without complaint and reaches nobody.
        # Every other signal still reads as success, so this is the only place
        # it gets said.
        if not plan["testers"]:
            print("  ! this group has no testers in it, so delivering to it reaches nobody")

        if plan["present"]:
            print(f"  build {build['version']} is already there. Nothing to do.")
            continue
        if not plan["actionable"]:
            print(f"  not adding build {build['version']}.")
            blocked += 1
            continue
        if not arguments.apply:
            print(f"  would add build {build['version']}. Re-run with --apply.")
            continue
        deliver(session, build, plan, arguments.submit)

    return 1 if blocked else 0


def _selftest() -> int:
    """Offline. The judgement calls, not the requests."""
    failures: list[str] = []

    def build(id_: str, version: str, uploaded: str, expired: bool = False) -> dict:
        return {"id": id_, "version": version, "uploaded": uploaded, "expired": expired}

    # The case this repo is actually in, and the reason this does not sort by
    # build number: release.sh uploads from 10000 up, Xcode Cloud uses its run
    # number, so the newest build has by far the smaller number. Sorting
    # numerically would pin testers to whatever was last shipped by hand.
    bands = [
        build("manual", "10001", "2026-08-01T09:00:00-07:00"),
        build("ci", "5", "2026-08-10T01:59:08-07:00"),
    ]
    if (newest := newest_build(bands)) is None or newest["id"] != "ci":
        failures.append(f"newest_build sorted by number, not date: {newest}")

    # And the other way round, so the test above is not passing by accident.
    if (newest := newest_build(bands[::-1])) is None or newest["id"] != "ci":
        failures.append("newest_build depends on the order the API returned")

    # An expired build is never the answer, however new.
    expired_newest = [
        build("a", "3", "2026-08-01T00:00:00-07:00"),
        build("b", "4", "2026-08-10T00:00:00-07:00", expired=True),
    ]
    if (newest := newest_build(expired_newest)) is None or newest["id"] != "a":
        failures.append(f"newest_build chose an expired build: {newest}")

    if newest_build([]) is not None:
        failures.append("newest_build invented a build from nothing")
    if newest_build([build("a", "1", "2026-01-01T00:00:00-07:00", expired=True)]) is not None:
        failures.append("newest_build returned an expired build as the only candidate")

    # One app record holds both platforms. Drop the filter and the newest upload
    # is as likely to be the Mac app, which cannot go to an iOS tester group.
    path = builds_path("123")
    if f"filter[preReleaseVersion.platform]={PLATFORM}" not in path:
        failures.append("builds_path lost the platform filter")
    if "filter[app]=123" not in path:
        failures.append("builds_path lost the app filter")

    # The pair that matters: one build, two states, opposite answers. Every
    # build archived before the workflow was given an audience looks like this,
    # and reading the external state for an internal group would refuse a
    # perfectly good build.
    internal_only = {
        "internalBuildState": "READY_FOR_BETA_TESTING",
        "externalBuildState": "NOT_APPLICABLE",
    }
    state, _, actionable = explain(True, internal_only)
    if not actionable or state != "READY_FOR_BETA_TESTING":
        failures.append("an INTERNAL_ONLY build was refused to the internal group")
    state, reason, actionable = explain(False, internal_only)
    if actionable or state != "NOT_APPLICABLE":
        failures.append("an INTERNAL_ONLY build was offered to an external group")
    if "INTERNAL_ONLY" not in reason:
        failures.append("the NOT_APPLICABLE explanation does not name the cause")

    # What build 4 actually reads today.
    eligible = {
        "internalBuildState": "READY_FOR_BETA_TESTING",
        "externalBuildState": "READY_FOR_BETA_SUBMISSION",
    }
    if not explain(True, eligible)[2] or not explain(False, eligible)[2]:
        failures.append("an eligible build was treated as undistributable")
    if explain(False, {"internalBuildState": "x", "externalBuildState": "IN_BETA_REVIEW"})[2]:
        failures.append("a build already in review would be re-added")
    if explain(True, {"internalBuildState": "PROCESSING", "externalBuildState": "x"})[2]:
        failures.append("a still-processing build was treated as ready")
    unknown = explain(True, {"internalBuildState": "SOMETHING_NEW", "externalBuildState": "x"})
    if unknown[2] or "SOMETHING_NEW" not in unknown[1]:
        failures.append("an unknown state was not reported as unknown")

    # The note format has to match ci_post_clone.sh exactly, or the check below
    # stops recognising the hook's own output and every build looks stale.
    if note_text("add a thing", "43c3b08b2f931d1999b1cd28ec3e78f3662c8a74", "9") != (
        "add a thing\n\nBuild 9 from 43c3b08b2f93\n"
    ):
        failures.append("note_text drifted from the format ci_post_clone.sh writes")

    if not note_names_build("add a thing\n\nBuild 9 from 43c3b08b2f93\n", "9"):
        failures.append("note_names_build rejected a build's own note")

    # The real failure: build 4 carrying build 3's note. Well-formed, plausible,
    # and about the wrong commit.
    if note_names_build("task update\n\nBuild 3 from e762f5c7d8d7\n", "4"):
        failures.append("note_names_build accepted another build's note")

    # `from ` is what stops build 1 matching build 10's note.
    if note_names_build("x\n\nBuild 10 from abc123456789\n", "1"):
        failures.append("note_names_build matched a build number by prefix")

    if note_names_build(None, "9") or note_names_build("", "9"):
        failures.append("note_names_build treated a missing note as present")

    # The marker is what the report prints, because subjects repeat: builds 3
    # and 6 were both "task update" and only the marker tells them apart.
    if note_claims("task update\n\nBuild 3 from e762f5c7d8d7\n") != "Build 3 from e762f5c7d8d7":
        failures.append("note_claims did not find the build marker")
    if note_claims("just a subject, no marker") is not None:
        failures.append("note_claims invented a marker")
    if note_claims(None) is not None:
        failures.append("note_claims invented a marker from nothing")

    if "App Manager" not in _hint(403) or ADMIN_KEY_ID not in _hint(403):
        failures.append("the 403 hint does not name the key")
    if _hint(200):
        failures.append("a hint was offered for a success")

    # The write key must not quietly become the read-only one.
    if ADMIN_KEY_ID == asc.KEY_ID:
        failures.append("the admin key is the Developer key, which cannot write")

    for failure in failures:
        print(f"  FAIL {failure}", file=sys.stderr)
    print(f"testflight_distribute selftest: 26 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    sys.exit(main())

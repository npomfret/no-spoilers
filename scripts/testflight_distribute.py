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
long as both paths stay in use. See docs/guides/building.md.

**One App Store record covers macOS and iOS**, so an unfiltered build list mixes
the two and the newest upload is as likely to be a Mac build. Every query here
is filtered to the one platform `--platform` names, and the choices come from
`asc.PLATFORM_FLAGS` so that the report covers whatever this can deliver to.

Choosing which build that is — filtered, unexpired, newest by upload date — is
`appstore_status`'s job, not a second copy here. The report walks the same list
to say which build the testers can actually install, and the two must agree
about what "newest" means or they will contradict each other in the same
terminal.

**It owns the *What to Test* note.** Xcode Cloud's own mechanism — a
`TestFlight/WhatToTest.en-GB.txt` file written into the checkout by a
`ci_post_clone.sh` hook — was tried here and removed. App Store Connect read
that file on some runs and not others: builds 3 and 9 carried their own note,
builds 4, 5 and 6 all carried build 3's. Every one of those runs logged the file
written correctly, the log bundles are indistinguishable, and no artifact Apple
exposes records whether the file was read, so there is nothing to debug and no
way to tell a working run from a broken one. This script asks the Xcode Cloud
run for the commit and writes `whatsNew` over the API instead, where the result
is visible and a failure is an HTTP error rather than silence.

The trade is that a build **nobody distributes now has no note at all**, and may
show a previous build's if App Store Connect carries one forward. That is the
right way round: an undistributed build reaches no tester, and the note becomes
correct at the moment it starts mattering.

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
    scripts/testflight_distribute.py --platform macos --apply
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

# Which platform's builds to hand over. Xcode Cloud has archived macOS as well
# as iOS since 2026-08-14, so "the newest build" stopped
# being a single thing on that date — one commit now produces an iOS build and
# a Mac build carrying the same number, and choosing between them is the
# caller's business.
#
# Shared with the report rather than spelled again here. It was a second copy
# until 2026-08-17, pinned to the report's single platform by a selftest guard;
# the two are now one dict, so a platform this command can deliver to is a
# platform the report covers by construction. That matters because the report is
# how you find out whether the delivery landed — a platform it cannot see is one
# where "nobody got it" and "all fine" are the same output.
PLATFORMS = asc.PLATFORM_FLAGS
DEFAULT_PLATFORM = "ios"

# The app's only TestFlight locale. A build with no localization in it shows
# testers nothing, which is why `write_note` can create one as well as set it.
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
    """The tester note for a build. This function defines the format.

    The subject says what changed; the `Build N from <sha>` line is what makes
    the note checkable afterwards. Keep both — a note that cannot be traced to a
    commit cannot be told apart from a stale one, which is the fault this whole
    mechanism exists to avoid.
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


def note_state(existing: dict | None) -> str:
    """How the note reads now, in the terms that decide what has to be written.

    The two empty-looking states are not the same thing. Apple creates an
    `en-GB` localization for every Xcode Cloud build and leaves its `whatsNew`
    null, so `is empty` means there is a record to `PATCH` and `has no en-GB
    localization` means one has to be `POST`ed. Both used to print `is missing`,
    and that one message was read as evidence that the create branch had run
    when it never has. A diagnostic that collapses two states produces a
    confident wrong answer rather than an obviously missing one.
    """
    if existing is None:
        return "has no en-GB localization"
    current = existing["whatsNew"]
    if not current:
        return "is empty"
    claim = note_claims(current)
    return f"claims {claim!r}" if claim else "has no build marker"


def source_commit(session: Session, product_id: str, version: str) -> dict | None:
    """The commit that produced this build, or None if Xcode Cloud did not.

    A build's version *is* its run number: Xcode Cloud rewrites CFBundleVersion
    to CI_BUILD_NUMBER when it exports the IPA, so the two cannot disagree. See
    docs/guides/building.md.

    None is a valid answer, not a swallowed error. `release.sh` uploads from
    10000 up and no run produced them, and a run started from Xcode by hand can
    carry no source commit at all. Neither has a commit to name, and inventing
    one would be worse than leaving the note alone.

    A product that does not exist is *not* one of those cases, which is why the
    id is found by `asc.find_ci_product` and passed in rather than looked up
    here. It was a constant until the product it named was deleted, and then
    every path through this script raised a bare 404 — including the dry run,
    which is the one that is supposed to be safe to run when things look wrong.

    `sort=-number` is required here — this endpoint answers oldest-first without
    it, so the newest runs fall off the end of the page.
    """
    if not version.isdigit():
        return None
    runs = session.get(f"/v1/ciProducts/{product_id}/buildRuns?limit=200&sort=-number")["data"]
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


def repair_note(session: Session, product_id: str, build: dict, apply: bool) -> None:
    """Make the note describe this build, or say why it cannot."""
    existing = note_on(session, build["id"])
    current = existing["whatsNew"] if existing else None
    if note_names_build(current, build["version"]):
        print("what to test: names this build already")
        return

    seen = note_state(existing)
    commit = source_commit(session, product_id, build["version"])
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


def testers(session: Session, group_id: str) -> list[dict]:
    return [
        {"email": t["attributes"]["email"], "state": t["attributes"]["state"]}
        for t in session.get(f"/v1/betaGroups/{group_id}/betaTesters?limit=200")["data"]
    ]


def gather(session: Session, only: str | None, platform: str) -> dict:
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

    builds = asc.platform_builds(session.get, app_id, platform)
    target = asc.newest_build(builds)
    if target is None:
        raise SystemExit(f"no unexpired {platform} builds on App Store Connect at all")

    detail = session.get(f"/v1/builds/{target['id']}/buildBetaDetail")["data"]["attributes"]
    holding = asc.groups_holding(session.get, target["id"])

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
    return {"appId": app_id, "build": target, "plans": plans}


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
    parser.add_argument(
        "--platform",
        choices=sorted(PLATFORMS),
        default=DEFAULT_PLATFORM,
        help="which platform's newest build to hand over. One run does one "
        "platform: every Xcode Cloud run now archives both, so the Mac build "
        "is a second, separate delivery decision and not a side effect of the "
        "iOS one.",
    )
    arguments = parser.parse_args([a for a in sys.argv[1:] if a != "--selftest"])

    platform = PLATFORMS[arguments.platform]
    session = Session()
    state = gather(session, arguments.group, platform)
    build = state["build"]
    print(f"newest {platform} build {build['version']}, uploaded {build['uploaded'][:16]}")

    # Found by the app it builds, never by its name — a hijacked product wears
    # the other project's name, so the name is the one field that lies. See
    # `asc.select_ci_product`.
    product_id = asc.find_ci_product(session.get, state["appId"])

    # The note belongs to the build, not to any group, so it is settled once
    # here rather than per group. It is also worth repairing on a build that is
    # already distributed: the testers have it, and what they were told about it
    # may still be describing somebody else's commit.
    repair_note(session, product_id, build, arguments.apply)
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

    # Choosing the build — `newest_build`, `live_builds`, `builds_path` — is
    # covered by `appstore_status --selftest`, which is where those live now
    # that the report walks the same list.

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

    # `note_text` and `note_names_build` are two halves of one agreement: what
    # is written must be what the staleness check recognises. Pinning the exact
    # string is what stops a change to one silently marking every build stale.
    if note_text("add a thing", "43c3b08b2f931d1999b1cd28ec3e78f3662c8a74", "9") != (
        "add a thing\n\nBuild 9 from 43c3b08b2f93\n"
    ):
        failures.append("note_text changed shape")
    if not note_names_build(note_text("s", "abcdef1234567890", "42"), "42"):
        failures.append("note_text and note_names_build disagree about the marker")

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

    # The two states that both used to read `is missing`. They differ in which
    # branch of `write_note` runs, so one message for both makes the report
    # useless as evidence about the write — which is exactly what happened.
    if note_state(None) != "has no en-GB localization":
        failures.append("note_state did not report an absent localization")
    if note_state({"id": "x", "whatsNew": None}) != "is empty":
        failures.append("note_state confused an empty localization with an absent one")
    if note_state({"id": "x", "whatsNew": ""}) != "is empty":
        failures.append("note_state did not treat empty text as empty")
    stale = {"id": "x", "whatsNew": "task update\n\nBuild 3 from e762f5c7d8d7\n"}
    if note_state(stale) != "claims 'Build 3 from e762f5c7d8d7'":
        failures.append("note_state did not report another build's marker")
    if note_state({"id": "x", "whatsNew": "just a subject"}) != "has no build marker":
        failures.append("note_state did not report a note carrying no marker")

    if "App Manager" not in _hint(403) or ADMIN_KEY_ID not in _hint(403):
        failures.append("the 403 hint does not name the key")
    if _hint(200):
        failures.append("a hint was offered for a success")

    # The write key must not quietly become the read-only one.
    if ADMIN_KEY_ID == asc.KEY_ID:
        failures.append("the admin key is the Developer key, which cannot write")

    # Every platform this script can deliver to must be one the report covers.
    # The report is what tells you whether this script's work landed, so a
    # platform missing from it is one where "nobody got the build" and "all fine"
    # are the same output — which is exactly what happened to macOS between
    # 2026-08-14 and 2026-08-17.
    #
    # This used to pin one default against one reported platform. Sharing the
    # dict makes that true by construction rather than by agreement, so what is
    # left to check is that nothing has been added on one side alone.
    uncovered = set(PLATFORMS.values()) - set(asc.TESTFLIGHT_PLATFORMS)
    if uncovered:
        failures.append(
            f"this script can deliver to {sorted(uncovered)}, which the report does not cover"
        )
    if DEFAULT_PLATFORM not in PLATFORMS:
        failures.append(f"the default platform {DEFAULT_PLATFORM!r} is not one this script accepts")

    # Apple spells this platform two ways and both appear in this repo. Guarding
    # the pair is cheaper than guessing which endpoint a future caller means.
    if PLATFORMS["macos"] != "MAC_OS":
        failures.append("the builds filter wants MAC_OS, not the CiPlatform spelling MACOS")

    for failure in failures:
        print(f"  FAIL {failure}", file=sys.stderr)
    print(f"testflight_distribute selftest: 28 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    sys.exit(main())

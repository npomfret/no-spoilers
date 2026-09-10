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
way to tell a working run from a broken one. This script writes `whatsNew` over
the API instead, where the result is visible and a failure is an HTTP error
rather than silence.

**The commit comes from git**, since the Xcode Cloud path was removed on 2026-09-09:
`release.sh` tags the archived commit `build/N` the moment the archive exists
(and, for builds 10001–10022, committed `bump to vX.Y.Z (build N)` on top of
it). Until 2026-08-22 the commit came from the run instead, and every 10000-band
build reached the testers blank because no run produced those numbers — build
10003 went out that way on the day the quota ran out. See `ship_commit`.

**The note is now the only record of the Xcode Cloud era.** Builds 1 to 125
carried their commit in a run's `sourceCommit` and nowhere else, and the runs are
no longer reachable — but the note this script wrote at the time still names it,
in `note_text`'s format. `note_commit` reads it back, and `tag_approved.py` asks
it last, after both git records. See `note_commit` for the three ways a note
lies and how each is refused.

The trade is that a build **nobody distributes now has no note at all**, and may
show a previous build's if App Store Connect carries one forward. That is the
right way round: an undistributed build reaches no tester, and the note becomes
correct at the moment it starts mattering.

A stale note is worse than no note: it describes changes the tester does not
have, and it looks entirely plausible while doing it. The check is therefore not
"is there a note" but "does the note name *this* build".

It writes through `asc_write.Session`, which `appstore_listing.py` also uses —
one App Manager key, spelled once. `appstore_status.py` stays a report and
issues `GET`s alone; keeping the reader apart from the writers is what makes it
safe to run whenever the answer is in doubt, and is why it holds a different key.

This one owns TestFlight: which build the testers get, and what they are told it
contains. The App Store listing — description, keywords, review notes, the
version record itself — is `appstore_listing.py` and does not belong here.

It refuses to act without `--apply`, and it will not submit anything for review
unless asked twice: adding a build to a group can be undone, and a review
submission cannot.

Internal groups only, unless `--group` names one. The public link is never fed
by accident.

**`--build N` names a build instead of taking the newest.** The newest upload is
the right default and stays the default; a named build is the other case, since
2026-09-06: the build attached to the App Store version was 104, two Xcode Cloud
runs had landed since, and the testers were meant to try the one Apple would be
reviewing. Same answer set as the default — unexpired builds of the platform —
so an expired number is refused rather than delivered. It is also how
`submit_build.py` delivers: always the number it just uploaded, never the newest.

**`--apply` ends by reading back what it wrote**, since 2026-09-10: the groups
hold the build and the note names it, or the run exits 1 saying which did not.
Nothing else looks, now that delivery runs unattended.

Usage:
    scripts/testflight_distribute.py                          # what would happen
    scripts/testflight_distribute.py --apply
    scripts/testflight_distribute.py --group Friends --apply --submit
    scripts/testflight_distribute.py --platform macos --apply
    scripts/testflight_distribute.py --platform macos --build 104 --apply
    scripts/testflight_distribute.py --selftest
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

import appstore_status as asc
from asc_write import ADMIN_KEY_ID, Session, _hint

REPO = Path(__file__).resolve().parent.parent

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


def note_marker(version: str, sha: str) -> str:
    """The line that identifies a note: which build, archived from which commit."""
    return f"Build {version} from {sha[:12]}"


def note_text(subject: str, sha: str, version: str) -> str:
    """The tester note for a build. This function defines the format.

    The subject says what changed; the `Build N from <sha>` line is what makes
    the note checkable afterwards. Keep both — a note that cannot be traced to a
    commit cannot be told apart from a stale one, which is the fault this whole
    mechanism exists to avoid.
    """
    return f"{subject}\n\n{note_marker(version, sha)}\n"


def note_names_build(whats_new: str | None, version: str) -> bool:
    """Whether this note is about this build, rather than merely present.

    The failure this exists for produces a note that is real, well-formed, and
    about a different build. `from ` is load-bearing: without it, build 1's
    marker matches build 10's note.

    **The number alone, and so only where nothing records the commit** —
    builds with no `build/N` tag and no bump commit. Wherever the commit is
    known, `note_names_commit` is the check.
    """
    return bool(whats_new) and f"Build {version} from " in whats_new


def note_names_commit(whats_new: str | None, version: str, sha: str) -> bool:
    """Whether this note names this build *and* the commit it was archived from.

    A note saying the right build came from the wrong commit passes
    `note_names_build`, and misleads a tester exactly as much as a note about
    another build. A whole line, so a subject that happens to read like a
    marker is not taken for one.
    """
    if not whats_new:
        return False
    return note_marker(version, sha) in (line.strip() for line in whats_new.splitlines())


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


# There was a `source_commit` here, asking `/v1/ciProducts/{id}/buildRuns` which
# commit an Xcode Cloud run built. It was the first of two answers, and
# `ship_commit` below was the fallback for builds no run produced. The Xcode
# Cloud delivery path was removed on 2026-09-09, so every build now arrives
# from `release.sh` carrying a `build/N` tag on the commit it archived, and the
# fallback is the whole answer. Builds 10001–10022 still have no tag and never
# will; `ship_commit` finds those by their bump commit, as it always did.


def note_commit(
    session: Session, app_id: str, platform: str, version: str, repo: Path = REPO
) -> dict | None:
    """The commit a build's own tester note names, or None if nothing usable.

    **The last record of the Xcode Cloud era, and the reason it is not lost.**
    Those builds carried their commit in the run's `sourceCommit` and nothing
    else; git never saw it, and the API that could ask went with that path. What
    survives is the note this script wrote at the time, in `note_text`'s
    format — `Build N from <sha>` — which is a machine-written primary record
    rather than somebody's recollection.

    Asked last, after the `build/N` tag and the bump commit, because it is a
    record of a record: the two git sources are the archive itself, and this is
    what the archive was reported to be. For any build shipped since 2026-09-05 the
    tag answers first and this is never reached.

    Three things have to hold before the answer is usable, and each is a way the
    note lies rather than a theoretical one:

    - **The note must name *this* build.** App Store Connect carries a previous
      build's note forward onto a build that has none, so a well-formed note
      about somebody else's commit is the ordinary failure here — the same one
      `repair_note` exists for. `note_names_build` is that check.
    - **The commit must exist in this checkout.** A note can outlive a
      force-push, and a sha that resolves to nothing is not a commit to tag.
    - **It must be on `main`.** A tag on a commit no branch contains is a tag
      nobody can reach.
    """
    builds = asc.all_pages(session.get, asc.builds_path(app_id, PLATFORMS[platform]))["data"]
    build = next((b for b in builds if b["attributes"]["version"] == version), None)
    if build is None:
        return None

    note = note_on(session, build["id"])
    whats_new = note["whatsNew"] if note else None
    if not note_names_build(whats_new, version):
        return None

    marker = note_claims(whats_new)
    sha = marker.split(" from ", 1)[1].strip() if marker else ""
    if not sha:
        return None

    try:
        full = git("rev-parse", "--verify", f"{sha}^{{commit}}", repo=repo).strip()
        git("merge-base", "--is-ancestor", full, "origin/main", repo=repo)
        subject = git("log", "-1", "--format=%s", full, repo=repo).strip()
    except subprocess.CalledProcessError:
        return None

    return {"subject": subject, "sha": full, "source": "the TestFlight note"}


def git(*arguments: str, repo: Path = REPO) -> str:
    """One git command against this checkout, or a hard stop.

    `-C REPO` rather than the working directory: this is run from wherever the
    caller happens to be, and a git answer about somebody else's checkout would
    be a confidently wrong note rather than a missing one. `repo` exists for
    the selftest, which builds a throwaway repository to exercise
    `ship_commit` against tags this one will only carry after the next ship.
    Shared with `tag_approved.py`, which writes the approval tag.
    """
    return subprocess.run(
        ("git", "-C", str(repo), *arguments),
        capture_output=True,
        text=True,
        check=True,
    ).stdout


def built_from_trailer(body: str) -> str | None:
    """The commit a bump commit says it was built from, or None if it does not say.

    **`release.sh` has recorded this since 2026-08-26 and every bump commit
    before that lacks it**, so absence is an ordinary answer about an older ship
    rather than a fault — `ship_commit` falls back to parentage for those. A
    trailer that is present but unreadable is a different thing entirely and
    stops the run: it means the one explicit record of what was built is
    corrupt, and parentage cannot be substituted for it, because the whole
    reason the trailer exists is that the bump commit may have been rebased and
    its parent may therefore be a commit nothing built.
    """
    found = []
    for line in body.splitlines():
        key, separator, value = line.partition(":")
        if separator and key.strip() == "Built-From":
            found.append(value.strip())

    if not found:
        return None
    if len(found) > 1:
        raise SystemExit(
            f"a bump commit carries {len(found)} Built-From trailers: {' '.join(found)}\n"
            "One ship is one archive, so there is no honest way to pick between them."
        )

    sha = found[0]
    if len(sha) != 40 or not all(character in "0123456789abcdef" for character in sha):
        raise SystemExit(
            f"a bump commit's Built-From trailer is not a commit id: {sha!r}\n"
            "It is written by release.sh from `git rev-parse HEAD` and nothing else "
            "should be editing it."
        )
    return sha


def ship_commit(version: str, repo: Path = REPO) -> dict | None:
    """The commit a local `release.sh` ship built, or None if no ship built it.

    **Asked only after Xcode Cloud has said no, and the order is load-bearing.**
    Build numbers are unique per upload path but not across them, and this repo
    already holds the collision: `bump to v1.0.21 (build 4)` sits in git while
    Xcode Cloud has its own iOS build 4. A run is authoritative about its own
    number, so CI answers first and git is only asked about numbers no run
    claims.

    **Since 2026-09-05 the record is the `build/N` tag, on the commit that was
    archived, and it is read first.** `release.sh` writes it the moment the
    archive exists, on HEAD, which nothing moves after the archive — so the
    tag says what was built directly and there is nothing to infer. It is the
    tip of `main` at the moment of the ship, which is exactly what Xcode
    Cloud's `sourceCommit` is for a run: the same fact by a different route.

    **Builds 10001 through 10022 have no tag and never will**, so for them the
    record is the `bump to vX.Y.Z (build N)` commit `release.sh` used to write
    after the archive, and the commit returned is the one that bump was built
    from, never the bump itself. Naming the bump in the note would give every
    ship the subject `bump to vX (build N)`, which repeats the marker line and
    tells a tester nothing. It is read from the bump's `Built-From:` trailer,
    and from parentage only when there is none: parentage was the original
    definition and it was true right up until `release.sh` learned to rebase
    the bump commit on 2026-08-26, after which a bump could sit on top of a
    commit that was never archived. Bumps before that date were never rebased
    and their parent is still the honest answer.

    Two consequences worth knowing before reading a note:

    - **A re-ship with no work in between names the same commit twice.** Build
      10002 followed 10001 with nothing between them, so its note reads `bump
      to v1.1.1 (build 10001)`; a second press today puts a second `build/`
      tag on the same commit and names it again. That is the honest answer —
      the build carries no change beyond its number.
    - **Anything uncommitted at ship time is in the build and not in the note.**
      `release.sh` refuses a dirty tree unless told `--allow-dirty`.

    Two ships claiming one build number is contradiction rather than absence, so
    it stops here instead of picking one.
    """
    if not version.isdigit():
        return None

    tag = f"build/{version}"
    if git("tag", "-l", tag, repo=repo).strip():
        # `rev-list -n1` looks through the annotation to the commit; `rev-parse`
        # of an annotated tag names the tag object.
        built = git("log", "-1", "--format=%H%x00%s", f"{tag}^{{commit}}", repo=repo).strip()
        sha, _, subject = built.partition("\0")
        return {"subject": subject, "sha": sha, "source": f"the {tag} tag"}

    # Anchored at both ends. Without the `$`, build 1000 matches the commit for
    # build 10001 — the same failure `note_names_build` guards on the way out.
    pattern = rf"^bump to v[0-9]+\.[0-9]+\.[0-9]+ \(build {version}\)$"
    bumps = git("log", "--format=%H", "--extended-regexp", f"--grep={pattern}", repo=repo).split()
    if not bumps:
        return None
    if len(bumps) > 1:
        raise SystemExit(
            f"{len(bumps)} commits claim to have shipped build {version}: {' '.join(bumps)}\n"
            "One build number is one ship. Until that is untangled, the note this would "
            "write is a guess about which."
        )

    recorded = built_from_trailer(git("log", "-1", "--format=%B", bumps[0], repo=repo))
    source = recorded if recorded is not None else f"{bumps[0]}^"

    try:
        built = git("log", "-1", "--format=%H%x00%s", source, repo=repo).strip()
    except subprocess.CalledProcessError:
        raise SystemExit(
            f"build {version}'s bump commit names {source} as what it built, and this "
            "clone does not have that commit.\n"
            "A shallow checkout would do that; so would a force-push that dropped it."
        ) from None

    sha, _, subject = built.partition("\0")
    return {"subject": subject, "sha": sha, "source": "the local ship commit"}


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


def repair_note(session: Session, build: dict, commit: dict | None, apply: bool) -> None:
    """Make the note describe this build and its commit, or say why it cannot.

    `commit` is `ship_commit`'s answer, asked once by the caller so this repair
    and the read-back after it judge the note against the same commit. **A note
    naming the right number from the wrong commit is rewritten**: until
    2026-09-10 it was left, because only the number was compared.
    """
    existing = note_on(session, build["id"])
    current = existing["whatsNew"] if existing else None
    seen = note_state(existing)

    if commit is None:
        if note_names_build(current, build["version"]):
            print("what to test: names this build already; nothing records its commit, so its sha is unchecked")
            return
        print(
            f"what to test: {seen}, and nothing names the commit behind build "
            f"{build['version']} — no build/ tag and no ship commit — so leaving it"
        )
        return

    if note_names_commit(current, build["version"], commit["sha"]):
        print("what to test: names this build and its commit already")
        return

    wanted = note_text(commit["subject"], commit["sha"], build["version"])
    marker = note_claims(wanted)
    # Where the commit came from, every time. The two paths are indistinguishable
    # in the note itself, and which one answered is the first thing worth knowing
    # when a note looks wrong.
    if not apply:
        print(f"what to test: {seen}. Would set {marker!r}, from {commit['source']}. "
              "Re-run with --apply.")
        return
    write_note(session, build["id"], existing, wanted)
    print(f"what to test: {seen}, now {marker!r}, from {commit['source']}")


def testers(session: Session, group_id: str) -> list[dict]:
    return [
        {"email": t["attributes"]["email"], "state": t["attributes"]["state"]}
        for t in session.get(f"/v1/betaGroups/{group_id}/betaTesters?limit=200")["data"]
    ]


def choose_build(builds: list[dict], number: str | None, platform: str) -> dict:
    """The build to hand over: the one named, or the newest upload.

    Both come from the same unexpired list, so a named build that has expired is
    refused the same way it would never have been chosen by default.
    """
    if number is None:
        target = asc.newest_build(builds)
        if target is None:
            raise SystemExit(f"no unexpired {platform} builds on App Store Connect at all")
        return target
    live = asc.live_builds(builds)
    target = next((b for b in live if b["version"] == number), None)
    if target is None:
        held = ", ".join(b["version"] for b in live[:8]) or "none"
        raise SystemExit(
            f"{platform} has no unexpired build {number} on App Store Connect (newest: {held})"
        )
    return target


def orphans(session: Session, app_id: str, platform: str, train: str) -> list[dict]:
    """The builds of one marketing version that nothing points at, on one platform.

    An orphan is a build **no tester group holds and no `appStoreVersions`
    record links to**. That is the whole definition, and both halves are read
    from App Store Connect rather than assumed: a build in a group is one
    somebody can install today, and a build behind a version record is one the
    store may still be serving or reviewing. Neither is this script's to expire.

    The definition is deliberately not "old", "superseded", or "untagged".
    Those describe how a build got here; only these two say whether taking it
    away removes something somebody has.

    **Expiring does not free the build number.** `highest_build` counts expired
    builds precisely because App Store Connect does, so this changes what can be
    installed and nothing about what can be uploaded next. See `appstore_status`.
    """
    live = asc.live_builds(asc.platform_builds(session.get, app_id, platform))
    in_train = asc.train_builds(session.get, app_id, platform).get(train, set())

    # One read per version record on this platform, not one per build: the
    # record names its build, so the set of spoken-for builds is settled once.
    records = session.get(
        f"/v1/apps/{app_id}/appStoreVersions?filter[platform]={platform}&include=build&limit=200"
    )
    spoken_for = {
        item["attributes"]["version"]
        for item in records.get("included") or []
        if item["type"] == "builds"
    }

    # By name, because a refusal has to say what it is protecting and a group
    # UUID says nothing to the person reading it.
    names = {
        group["id"]: group["attributes"]["name"]
        for group in session.get(f"/v1/apps/{app_id}/betaGroups?limit=50")["data"]
    }

    found = []
    for build in sorted((b for b in live if b["version"] in in_train), key=lambda b: b["uploaded"]):
        holders = asc.groups_holding(session.get, build["id"])
        found.append(
            {
                **build,
                "groups": sorted(names.get(h, h) for h in holders),
                "spoken_for": build["version"] in spoken_for,
                "orphan": not holders and build["version"] not in spoken_for,
            }
        )
    return found


def expire(session: Session, build: dict, apply: bool) -> None:
    """Stop one build launching. There is no way back from this.

    `expired` is the only writable attribute on a build that matters here, and
    App Store Connect offers no unexpire — the build stays in the list, keeps
    its number, and can never be installed again.
    """
    if not apply:
        print(f"  build {build['version']} would be expired")
        return
    session.patch(
        f"/v1/builds/{build['id']}",
        {"data": {"type": "builds", "id": build["id"], "attributes": {"expired": True}}},
    )
    print(f"  build {build['version']} expired")


def gather(session: Session, only: str | None, platform: str, number: str | None) -> dict:
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

    target = choose_build(asc.platform_builds(session.get, app_id, platform), number, platform)

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


def add_to_group(session: Session, build: dict, plan: dict) -> str:
    """Put the build in the group, and say which way it got there.

    **Apple attaches some builds to an internal group on its own, and then
    refuses the add.** FunMax, on the same team, measured it: `POST
    /v1/betaGroups/{id}/relationships/builds` answers `422
    ENTITY_UNPROCESSABLE`, *"Builds cannot be assigned to this internal
    group"*, for a build Apple had already attached, and accepts the same call
    for one it had not. Which builds Apple takes is not known, so neither the
    add nor the refusal can be skipped, and the refusal is settled against the
    group's contents. The window is the few seconds after processing ends,
    which is exactly when `submit_build.py` calls this — FunMax's Ship #5 exited
    1 having uploaded, processed and delivered its build, for want of this.
    """
    try:
        session.post(
            f"/v1/betaGroups/{plan['id']}/relationships/builds",
            {"data": [{"type": "builds", "id": build["id"]}]},
        )
        return f"added build {build['version']} to {plan['name']}"
    except SystemExit:
        if plan["id"] not in asc.groups_holding(session.get, build["id"]):
            raise
        return f"build {build['version']} is in {plan['name']}: Apple added it first"


def unconfirmed(session: Session, build: dict, commit: dict | None, plans: list[dict]) -> list[str]:
    """What an `--apply` run set out to do that App Store Connect does not show.

    Read back after the writes rather than inferred from their status codes.
    A 204 from the group add and a 200 from the note are what every other
    signal in this pipeline already was — success-shaped — and the delivery
    this exists for is the one nobody is watching: `submit_build.py` runs it
    unattended and reports what this returns.

    A plan that was refused as not actionable is not demanded here; it has
    already been counted as blocked. The note is demanded whatever happened to
    the groups, because a build a tester holds with a note about another
    commit is the failure these checks were written for. **Against the commit
    whenever one is known**, `commit` being the same `ship_commit` answer the
    repair used: a note naming the right number from the wrong commit is not a
    delivery confirmed.
    """
    gaps = []
    holding = asc.groups_holding(session.get, build["id"])
    for plan in plans:
        if (plan["present"] or plan["actionable"]) and plan["id"] not in holding:
            gaps.append(f"{plan['name']} does not hold build {build['version']}")
    note = note_on(session, build["id"])
    whats_new = note["whatsNew"] if note else None
    if commit is None:
        if not note_names_build(whats_new, build["version"]):
            gaps.append(f"the tester note does not name build {build['version']}")
    elif not note_names_commit(whats_new, build["version"], commit["sha"]):
        gaps.append(f"the tester note does not say {note_marker(build['version'], commit['sha'])!r}")
    return gaps


def deliver(session: Session, build: dict, plan: dict, submit: bool) -> None:
    print(f"  {add_to_group(session, build, plan)}")

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
    parser.add_argument(
        "--build",
        metavar="N",
        help="hand over this build number instead of the newest upload — the one "
        "attached to the App Store version, ordinarily.",
    )
    parser.add_argument(
        "--expire",
        metavar="VERSION",
        help="the opposite errand: stop every orphan build of this marketing "
        "version launching, on --platform. An orphan is a build no tester group "
        "holds and no App Store version record points at; anything else is "
        "listed and refused. Not reversible, and it does not free the build "
        "numbers. Needs --apply.",
    )
    arguments = parser.parse_args([a for a in sys.argv[1:] if a != "--selftest"])

    platform = PLATFORMS[arguments.platform]
    session = Session()

    if arguments.expire:
        app_id = asc.find_app(session.get)["id"]
        found = orphans(session, app_id, platform, arguments.expire)
        if not found:
            print(f"{platform} {arguments.expire} holds no unexpired builds")
            return 0
        print(f"{platform} {arguments.expire}: {len(found)} unexpired builds")
        for build in found:
            if build["orphan"]:
                expire(session, build, arguments.apply)
                continue
            held = ", ".join(build["groups"])
            why = "attached to an App Store version record" if build["spoken_for"] else f"held by {held}"
            print(f"  build {build['version']} kept — {why}")
        if not arguments.apply:
            print("\nnothing was changed. re-run with --apply. that cannot be undone.")
        return 0
    state = gather(session, arguments.group, platform, arguments.build)
    build = state["build"]
    chosen = "named" if arguments.build else "newest"
    print(f"{chosen} {platform} build {build['version']}, uploaded {build['uploaded'][:16]}")

    # The note belongs to the build, not to any group, so it is settled once
    # here rather than per group. It is also worth repairing on a build that is
    # already distributed: the testers have it, and what they were told about it
    # may still be describing somebody else's commit.
    #
    # The `build/N` tag that names the commit was pushed by whichever machine
    # shipped — a TeamCity agent, ordinarily — and this one may not have seen
    # it. Without the fetch a stale clone reads as "nothing names the commit
    # behind build N" and leaves the note blank, silently. That tag is now the
    # only answer, so the fetch is the whole of the lookup.
    git("fetch", "--quiet", "--tags", "origin")
    commit = ship_commit(build["version"])
    repair_note(session, build, commit, arguments.apply)
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

    if not arguments.apply:
        return 1 if blocked else 0

    print()
    gaps = unconfirmed(session, build, commit, state["plans"])
    for gap in gaps:
        print(f"! not confirmed: {gap}")
    if not gaps:
        named = "it and its commit" if commit else "it"
        print(f"confirmed: build {build['version']}'s note names {named}, and every group given it holds it")
    return 1 if blocked or gaps else 0


def _selftest() -> int:
    """Offline. The judgement calls, not the requests."""
    failures: list[str] = []

    # Choosing the build — `newest_build`, `live_builds`, `builds_path` — is
    # covered by `appstore_status --selftest`, which is where those live now
    # that the report walks the same list. What is decided here is only the
    # `--build` case: a named build comes from the same unexpired list, so a
    # number that has expired is refused and the newest is not silently taken.
    shaped = [
        {"id": "new", "version": "106", "uploaded": "2026-09-06T03:20:00", "expired": False,
         "processingState": "VALID"},
        {"id": "old", "version": "104", "uploaded": "2026-09-05T13:11:00", "expired": False,
         "processingState": "VALID"},
        {"id": "gone", "version": "15", "uploaded": "2026-08-14T10:00:00", "expired": True,
         "processingState": "VALID"},
    ]
    try:
        if choose_build(shaped, None, "MAC_OS")["id"] != "new":
            failures.append("without --build the newest upload was not chosen")
        if choose_build(shaped, "104", "MAC_OS")["id"] != "old":
            failures.append("--build 104 did not choose build 104")
    except SystemExit as error:
        failures.append(f"choosing from a live list refused: {error}")
    try:
        choose_build(shaped, "15", "MAC_OS")
        failures.append("an expired build was chosen by number")
    except SystemExit:
        pass

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

    # `built_from_trailer` is exercised directly rather than through history,
    # because the first bump commit carrying a trailer will be written by the
    # next ship and there is nothing to read until then. A parser whose only
    # test is "the repo happens to contain one" is untested for every case that
    # matters, and the cases that matter here are the malformed ones.
    SHA = "0123456789abcdef0123456789abcdef01234567"
    if built_from_trailer(f"bump to v1.1.2 (build 10010)\n\nBuilt-From: {SHA}\n") != SHA:
        failures.append("built_from_trailer did not read a well-formed trailer")
    if built_from_trailer("bump to v1.1.1 (build 10001)\n") is not None:
        failures.append("built_from_trailer invented a trailer for a commit without one")
    # The pre-2026-08-26 bump commits are exactly this shape, and reading them as
    # anything but "no trailer" would send ship_commit to a bogus revision
    # instead of to the parent that is still correct for them.
    if built_from_trailer("bump to v1.0.21 (build 4)") is not None:
        failures.append("built_from_trailer found a trailer in a single-line message")
    # Truncated, uppercased and non-hex all mean the same thing: the one explicit
    # record of what was built cannot be trusted, and parentage is not a
    # substitute for it once rebasing is possible.
    for broken in ("Built-From: 0123456", f"Built-From: {SHA.upper()}", "Built-From: HEAD~1"):
        try:
            built_from_trailer(f"bump to v1.1.2 (build 10010)\n\n{broken}\n")
            failures.append(f"built_from_trailer accepted {broken!r} as a commit id")
        except SystemExit:
            pass
    try:
        built_from_trailer(f"bump\n\nBuilt-From: {SHA}\nBuilt-From: {SHA}\n")
        failures.append("built_from_trailer picked between two Built-From trailers")
    except SystemExit:
        pass

    # `ship_commit` against this repo's own history, which is the only place the
    # thing it parses exists. Build 10003 is the ship that made the gap concrete:
    # shipped locally on 2026-08-22 with Xcode Cloud out of quota, and it reached
    # the internal testers with an empty note.
    shipped = ship_commit("10003")
    if shipped is None:
        failures.append("ship_commit found no ship for build 10003, which release.sh shipped")
    else:
        if not shipped["sha"].startswith("8d7af11"):
            failures.append(f"ship_commit named {shipped['sha'][:12]} rather than build 10003's tip")
        if shipped["subject"].startswith("bump to v"):
            failures.append("ship_commit returned the bump commit rather than the commit it built")
        if not note_names_build(
            note_text(shipped["subject"], shipped["sha"], "10003"), "10003"
        ):
            failures.append("a note built from ship_commit does not name its own build")

    # The anchor. `(build 10001)` contains `1000`, and an unanchored grep would
    # hand build 1000 another build's commit — well-formed, plausible, wrong.
    if ship_commit("1000") is not None:
        failures.append("ship_commit matched a build number by prefix")

    # The `build/N` tag, against a throwaway repository: this one carries no
    # such tag until the first ship that writes one, and a reader whose only
    # test is "the repo happens to contain one" is untested until then. Three
    # shapes — tag alone, bump alone, and both on one build — and the two
    # records have to agree when both are present, because the tag is written
    # on the commit the bump used to name in its trailer.
    import tempfile

    with tempfile.TemporaryDirectory() as scratch:
        throwaway = Path(scratch)
        git("init", "--quiet", "--initial-branch=main", repo=throwaway)
        git("config", "user.email", "selftest@example.invalid", repo=throwaway)
        git("config", "user.name", "selftest", repo=throwaway)
        git("commit", "--quiet", "--allow-empty", "-m", "the work", repo=throwaway)
        work = git("rev-parse", "HEAD", repo=throwaway).strip()
        git("tag", "-a", "build/10023", "-m", "v1.1.3 build 10023", repo=throwaway)
        git("commit", "--quiet", "--allow-empty", "-m", "bump to v1.1.3 (build 10023)",
            "-m", f"Built-From: {work}", repo=throwaway)
        git("commit", "--quiet", "--allow-empty", "-m", "bump to v1.1.3 (build 10024)",
            "-m", f"Built-From: {work}", repo=throwaway)
        git("commit", "--quiet", "--allow-empty", "-m", "later work", repo=throwaway)
        later = git("rev-parse", "HEAD", repo=throwaway).strip()
        git("tag", "-a", "build/10025", "-m", "v1.1.3 build 10025", repo=throwaway)

        tagged = ship_commit("10025", repo=throwaway)
        if tagged is None or tagged["sha"] != later or tagged["subject"] != "later work":
            failures.append(f"ship_commit did not read the build/ tag: {tagged}")
        elif "build/10025" not in tagged["source"]:
            failures.append("ship_commit read the tag and did not say so")

        bumped = ship_commit("10024", repo=throwaway)
        if bumped is None or bumped["sha"] != work:
            failures.append(f"ship_commit lost the bump-commit path for an untagged build: {bumped}")

        both = ship_commit("10023", repo=throwaway)
        if both is None or both["sha"] != work:
            failures.append(f"ship_commit gave a different answer with both records present: {both}")
        elif "build/10023" not in both["source"]:
            failures.append("ship_commit preferred the bump commit to the tag")

        if ship_commit("10026", repo=throwaway) is not None:
            failures.append("ship_commit invented a ship in a repository holding neither record")

        # `note_commit` reads back what `note_text` wrote, so the two are tested
        # against each other rather than against a hand-typed marker line: a
        # change to the format that forgets the reader fails here.
        #
        # The guards matter more than the happy path. A note carried forward
        # onto a build that has none is App Store Connect's ordinary behaviour,
        # so "well-formed note about a different build" is the case that must
        # answer None rather than a plausible wrong commit. A sha that no longer
        # resolves is the other: notes outlive force-pushes.
        git("branch", "--force", "origin/main", "HEAD", repo=throwaway)

        class _Notes:
            """Enough of a Session to answer the two GETs `note_commit` makes."""

            def __init__(self, whats_new: str | None) -> None:
                self.whats_new = whats_new

            def get(self, path: str) -> dict:
                if "betaBuildLocalizations" in path:
                    return {"data": [{"id": "loc", "attributes": {
                        "locale": NOTE_LOCALE, "whatsNew": self.whats_new}}]}
                return {"data": [{"id": "b", "attributes": {"version": "104"}}]}

        honest = _Notes(note_text("later work", later, "104"))
        found = note_commit(honest, "6761343835", "macos", "104", repo=throwaway)
        if found is None or found["sha"] != later:
            failures.append(f"note_commit did not read back what note_text wrote: {found}")
        elif found["source"] != "the TestFlight note":
            failures.append("note_commit did not say the note answered")

        stale = _Notes(note_text("the work", work, "103"))
        if note_commit(stale, "6761343835", "macos", "104", repo=throwaway) is not None:
            failures.append("note_commit trusted a note about a different build")

        for unusable in (None, "", "no marker line here", "Build 104 from cafebabecafe"):
            if note_commit(_Notes(unusable), "6761343835", "macos", "104", repo=throwaway):
                failures.append(f"note_commit accepted an unusable note: {unusable!r}")

    # Absence is an answer here: every Xcode Cloud build reaches this function
    # having already been refused by `source_commit`, and none of them has a
    # ship commit. Returning something would be inventing one.
    if ship_commit("999999") is not None:
        failures.append("ship_commit invented a ship for a build nothing shipped")
    if ship_commit("not-a-number") is not None:
        failures.append("ship_commit tried to parse a version that is not a build number")

    # Apple's own add, and the 422 it then answers. Settled against the group's
    # contents both ways: a build that is there arrived however it arrived, and
    # a refusal for a build no group holds is a real failure.
    class _RefusesTheAdd:
        def __init__(self, holding: list[str]) -> None:
            self.holding = holding
            self.posts = 0

        def get(self, path: str) -> dict:
            return {"included": [{"id": group} for group in self.holding]}

        def post(self, path: str, body: dict) -> dict:
            self.posts += 1
            raise SystemExit(
                f"POST {path} -> HTTP 422\n"
                '{"errors":[{"code":"ENTITY_UNPROCESSABLE","title":'
                '"Builds cannot be assigned to this internal group."}]}'
            )

    handed = {"id": "b1", "version": "10025"}
    internal = {"id": "g1", "name": "Internal", "internal": True}
    already = _RefusesTheAdd(["g1"])
    try:
        said = add_to_group(already, handed, internal)
        if "Apple added it first" not in said:
            failures.append(f"an add Apple had already made was not reported as such: {said!r}")
    except SystemExit as refusal:
        failures.append(f"a build already in the group failed the delivery: {refusal}")
    if already.posts != 1:
        failures.append("the add was not attempted, so a build Apple ignores would strand")
    try:
        add_to_group(_RefusesTheAdd([]), handed, internal)
        failures.append("a refusal was swallowed for a build no group holds")
    except SystemExit:
        pass

    # The read-back after --apply, and the repair before it. All delivered, a
    # group that does not hold what it was given, a note about another build —
    # and a note naming this build from another commit, which both the repair
    # and the read-back accepted until 2026-09-10.
    class _Delivered:
        def __init__(self, holding: list[str], whats_new: str | None) -> None:
            self.holding, self.whats_new = holding, whats_new
            self.written: list[str] = []

        def get(self, path: str) -> dict:
            if "betaBuildLocalizations" in path:
                return {"data": [{"id": "loc", "attributes": {"locale": NOTE_LOCALE, "whatsNew": self.whats_new}}]}
            return {"included": [{"id": group} for group in self.holding]}

        def patch(self, path: str, body: dict) -> dict:
            self.written.append(body["data"]["attributes"]["whatsNew"])
            return {}

    given = [{"id": "g1", "name": "Internal", "present": False, "actionable": True}]
    refused = {"id": "g2", "name": "Friends", "present": False, "actionable": False}
    reserved = {"subject": "the work", "sha": "0123456789abcdef" * 2 + "01234567", "source": "the build/10025 tag"}
    right_note = note_text(reserved["subject"], reserved["sha"], "10025")
    other_commit = note_text("the work", "fedcba9876543210" * 2 + "fedcba98", "10025")
    if unconfirmed(_Delivered(["g1"], right_note), handed, reserved, given + [refused]):
        failures.append("a delivered build with its own note was not confirmed")
    if not any("Internal does not hold" in gap
               for gap in unconfirmed(_Delivered([], right_note), handed, reserved, given)):
        failures.append("a group that does not hold the build it was given was confirmed")
    if not any("tester note" in gap
               for gap in unconfirmed(_Delivered(["g1"], note_text("old", "abc", "10024")), handed, reserved, given)):
        failures.append("a note about another build was confirmed")
    if not any("tester note" in gap
               for gap in unconfirmed(_Delivered(["g1"], other_commit), handed, reserved, given)):
        failures.append("a note naming this build from another commit was confirmed")
    if unconfirmed(_Delivered(["g1"], other_commit), handed, None, given):
        failures.append("a build nothing records the commit of was held to a commit")
    shaped_like_it = f"Build 10025 from {reserved['sha'][:12]} was the plan\n\n{note_marker('10025', 'fedcba987654')}\n"
    if note_names_commit(shaped_like_it, "10025", reserved["sha"]):
        failures.append("a subject shaped like the marker was taken for the marker")

    import contextlib
    import io

    mislabeled, settled = _Delivered([], other_commit), _Delivered([], right_note)
    with contextlib.redirect_stdout(io.StringIO()):
        repair_note(mislabeled, handed, reserved, apply=True)
        repair_note(settled, handed, reserved, apply=True)
    if mislabeled.written != [right_note]:
        failures.append("repair_note left a note naming this build from another commit")
    if settled.written:
        failures.append("repair_note rewrote a note already naming the build and its commit")

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
    print(f"testflight_distribute selftest: 59 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    sys.exit(main())

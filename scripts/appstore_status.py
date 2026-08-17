#!/usr/bin/env python3
"""What App Store Connect currently holds for this app, and what needs a person.

One app record covers both platforms — macOS and iOS share
`pomocorp.NoSpoilers.NoSpoilersMac` under Universal Purchase — so the two live
almost separate lives in App Store Connect: separate versions, separate listing
text, separate screenshots, separate review submissions, and one shared set of
app-level answers. Nothing in the UI shows them side by side, and the state that
matters most is the easiest to miss: **on 2026-08-09 the macOS 1.0.21 was
READY_FOR_SALE while the iOS 1.0.21 of the same version number had been
REJECTED for three months.** This prints both.

It also reports TestFlight, where the thing worth knowing is not what exists but
**which build the testers can actually install**. Handing a build over is a
command somebody runs — see docs/guides/building.md — so the newest build
reaching nobody is the ordinary state after every push, and
warning about it would leave this permanently red. Being *behind* is reported
and never chased; only being able to install nothing at all is a problem.

**Both platforms, since every Xcode Cloud run archives both.** The tester groups
are app-wide and printed once; the walk that finds the installable build is per
platform and runs twice.

It issues `GET`s and nothing else. `scripts/release.sh` remains the only thing
here that uploads or submits anything, and `scripts/testflight_distribute.py`
the only one that hands a build to a group — it shares the build-selection
helpers below so the two cannot disagree about which build is newest.

**Two required pages cannot be read at all, and are printed as unknown rather
than left out.** App Privacy — the data-collection questionnaire — has no App
Store Connect API endpoint anywhere; fastlane authenticates with an Apple ID web
session for that one action precisely because none exists. Price and
availability are in the API and refused to a Developer-level key. A checklist
that silently omits a required item reads as a finished checklist.

**Rejection reasons are not in this API either.** Three states are readable and
no prose is: a version reads `REJECTED`, its submission reads
`UNRESOLVED_ISSUES`, and each item inside that submission reads `REJECTED` or
`APPROVED` — which says *what* was refused when a submission holds more than the
version alone. Why is another matter. Resolution Center has no endpoint at all,
not a forbidden one: `/v1/resolutionCenterThreads` and
`/v1/resolutionCenterMessages` both answer `PATH_ERROR ... does not exist`, as
does the relationship spelling off the app. What App Review said is in the
browser.

The exit code is the answer to "is anything waiting on me": 0 when nothing this
report can see needs a person, 1 when something does.

Stdlib only. The ES256 token is built from `openssl` and twenty lines of ASN.1
rather than a Ruby or Python dependency tree, so this runs on a clean machine
with nothing installed. It uses the same key, issuer and app as
`scripts/ship-ios.sh`.

Usage:
    scripts/appstore_status.py
    scripts/appstore_status.py --json
    scripts/appstore_status.py --selftest
"""

from __future__ import annotations

import argparse
import base64
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from collections.abc import Callable
from pathlib import Path

API = "https://api.appstoreconnect.apple.com"

# The same three values `scripts/ship-ios.sh` and `scripts/ship-appstore.sh`
# pass to `release.sh`. Constants rather than flags because a report that
# silently described a different app would be worse than one that fails.
BUNDLE_ID = "pomocorp.NoSpoilers.NoSpoilersMac"
KEY_ID = "S394C74APG"
ISSUER_ID = "69a6de6e-6d3e-47e3-e053-5b8c7c11a4d1"


def key_path(key_id: str) -> Path:
    """Where a downloaded App Store Connect key lives.

    A function rather than one constant because this is not the only key:
    `scripts/testflight_distribute.py` needs an App Manager key, and this one is
    Developer level. Same directory, same naming — Apple's own.
    """
    return Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{key_id}.p8"


KEY_PATH = key_path(KEY_ID)

# App Store Connect rejects a token older than twenty minutes. A run is well
# inside that; this is not a session.
TOKEN_LIFETIME = 1200
TIMEOUT = 30

# Screenshot display types are one Apple enum covering every device Apple has
# shipped, and the smaller sizes are derived from the largest in each family, so
# what matters is whether a family has any images at all. Grouped by platform
# because an iPad set on a macOS version means nothing.
FAMILIES = {
    "IOS": (("iPhone", "APP_IPHONE"), ("iPad", "APP_IPAD")),
    "MAC_OS": (("desktop", "APP_DESKTOP"),),
}

# What each App Store state means for the only question worth asking: is
# somebody expected to do something. Apple's vocabulary mixes "you are editing
# this", "Apple is looking at it" and "it is out" into one field.
WORKING = {
    "PREPARE_FOR_SUBMISSION": "being written",
    "DEVELOPER_REJECTED": "you pulled it back",
    "REJECTED": "App Review said no",
    "METADATA_REJECTED": "App Review objected to the listing, not the binary",
    "INVALID_BINARY": "the build was refused",
    "PENDING_DEVELOPER_RELEASE": "approved, waiting for you to release it",
}
WAITING = {
    "WAITING_FOR_REVIEW": "queued at Apple",
    "IN_REVIEW": "Apple is looking at it",
    "PENDING_APPLE_RELEASE": "approved, Apple releases it",
    "PROCESSING_FOR_APP_STORE": "publishing",
}

# The listing fields App Store Connect will not accept a submission without,
# under the names this report prints. Everything else is reported and never
# chased: a marketing URL is a decision, not an omission.
REQUIRED_TEXT = (
    ("description", "description"),
    ("keywords", "keywords"),
    ("supportUrl", "support URL"),
)

CONTACT = (
    ("contactFirstName", "first name"),
    ("contactLastName", "last name"),
    ("contactEmail", "email"),
    ("contactPhone", "phone"),
)

# Read from App Review details, and deliberately not all of them: the response
# carries `demoAccountPassword` in the clear, and a status report — especially
# one with a `--json` mode whose output ends up pasted somewhere — has no reason
# to hold a password at all. Whether one is set is the only part worth knowing.
REVIEW_FIELDS = tuple(key for key, _ in CONTACT) + ("demoAccountName", "demoAccountRequired", "notes")

# The platforms this report's TestFlight section covers, in the order it prints
# them.
#
# It was `IOS` alone until 2026-08-17, written when the Mac app had no
# TestFlight story at all. Xcode Cloud began archiving macOS on 2026-08-14, so
# from that day **every push uploaded a Mac build this section could not see** —
# and a stranded Mac build printed identically to no Mac build, which is the one
# failure the section exists to catch. Measured on macOS 1.1.1 build 15:
# `processingState VALID`, `include=betaGroups` empty, report silent.
#
# Every platform `testflight_distribute.py` can deliver to has to appear here,
# because the report is what tells you whether a delivery landed: a platform it
# cannot see is one where "nothing was handed over" and "everything is fine" are
# the same output. That is guaranteed rather than checked — the command builds
# its `--platform` choices from this same dict, so the two cannot drift the way
# two constants in two files could.
#
# **Apple spells this platform two ways and both appear in this repo.** These
# are the `filter[preReleaseVersion.platform]` values that `/v1/builds` wants;
# the Xcode Cloud action's `CiPlatform` calls the same platform `MACOS`. Only
# one is ever right in a given call.
PLATFORM_FLAGS = {"ios": "IOS", "macos": "MAC_OS"}
TESTFLIGHT_PLATFORMS = tuple(PLATFORM_FLAGS.values())


def platform_flag(platform: str) -> str:
    """The `--platform` value that hands a build over on this platform.

    Absence is a programming error rather than a state to report: every platform
    the report covers is one the command can deliver to, which is the property
    the shared dict above exists to hold.
    """
    flag = next((f for f, value in PLATFORM_FLAGS.items() if value == platform), None)
    if flag is None:
        raise SystemExit(f"no --platform flag delivers to {platform}")
    return flag

# How far back to walk looking for a build some tester group holds. Handing a
# build over is a command somebody runs rather than a post-action —
# docs/guides/building.md — so the newest builds sit
# in no group as a matter of course, and this walk is the ordinary path rather
# than a fallback.
#
# It was ten, on the reasoning that anything further back means nothing has been
# delivered in a long time. Measured on 2026-08-17, the day macOS joined this
# section: **the macOS answer sat at position eleven.** Mac testers were on
# build 10001 and the walk stopped one short of finding it, so the platform
# reported as delivering nothing when it was merely behind. Twenty covers every
# live Mac build there is today with room to spare, and the walk stops at the
# first hit, so the cost is only paid when the answer really is a long way back.
DISTRIBUTION_WALK = 20


def _b64(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """An ECDSA DER signature as the 64-byte `r || s` that JOSE requires.

    `openssl dgst -sign` emits `SEQUENCE { INTEGER r, INTEGER s }`; ES256 wants
    the two values bare, each left-padded to 32 bytes. DER stores them signed,
    so a value whose top bit is set carries a leading zero that must come off
    and a short value needs padding back on — get either wrong and the signature
    verifies locally and Apple returns 401.
    """
    if not der or der[0] != 0x30:
        raise ValueError("not a DER SEQUENCE")
    index = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        if der[index] != 0x02:
            raise ValueError("expected a DER INTEGER")
        length = der[index + 1]
        value = der[index + 2 : index + 2 + length].lstrip(b"\x00")
        if len(value) > 32:
            raise ValueError("integer wider than P-256")
        out += value.rjust(32, b"\x00")
        index += 2 + length
    return out


def token(issuer: str, key_id: str, key_file: Path, now: int | None = None) -> str:
    """A signed ES256 bearer token. The key is read by openssl, never by us."""
    issued = int(time.time()) if now is None else now
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {
        "iss": issuer,
        "iat": issued,
        "exp": issued + TOKEN_LIFETIME,
        "aud": "appstoreconnect-v1",
    }
    signing_input = f"{_b64(json.dumps(header).encode())}.{_b64(json.dumps(claims).encode())}"
    signed = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key_file)],
        input=signing_input.encode(),
        capture_output=True,
        check=True,
    )
    return f"{signing_input}.{_b64(der_to_raw(signed.stdout))}"


class Client:
    """GET-only. There is no post, put or patch here, by design."""

    def __init__(self) -> None:
        if not KEY_PATH.exists():
            raise SystemExit(
                f"no private key at {KEY_PATH}\n"
                "It is the one scripts/ship-ios.sh already uses, downloadable once from "
                "App Store Connect > Users and Access > Integrations."
            )
        self.bearer = token(ISSUER_ID, KEY_ID, KEY_PATH)

    def get(self, path: str) -> dict:
        request = urllib.request.Request(
            API + path, headers={"Authorization": f"Bearer {self.bearer}"}
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:400]
            raise SystemExit(f"GET {path} -> HTTP {error.code}\n{detail}")


def _text(value: object) -> str:
    """Blank, null and whitespace are the same answer: nothing is filled in."""
    return str(value).strip() if value is not None else ""


def screenshot_families(platform: str, sets: list[dict]) -> dict[str, int | None]:
    """How many screenshots each device family has, for this platform's families.

    Counts images rather than sets. An empty set is exactly what App Store
    Connect leaves behind when an upload fails, and a declared-but-empty slot is
    refused at the end of a submission rather than the start.

    `None` means a set exists whose images could not be counted, which is not the
    same as none and must never be chased: `meta.paging` is only populated when
    the request asks to include the screenshots, so a caller that forgets would
    otherwise manufacture a problem that is not there.
    """
    counts: dict[str, int | None] = {name: 0 for name, _ in FAMILIES.get(platform, ())}
    for entry in sets:
        display = entry["display"] or ""
        for name, prefix in FAMILIES.get(platform, ()):
            if not display.startswith(prefix):
                continue
            if entry["count"] is None:
                counts[name] = None
            elif counts[name] is not None:
                counts[name] += entry["count"]
    return counts


def _screenshot_sets(client: Client, localization_id: str) -> list[dict]:
    # `include=appScreenshots` is load-bearing: without it every set comes back
    # with no `meta.paging` and every count reads as unknown.
    response = client.get(
        f"/v1/appStoreVersionLocalizations/{localization_id}"
        "/appScreenshotSets?limit=50&include=appScreenshots"
    )
    sets = []
    for entry in response["data"]:
        paging = (
            ((entry.get("relationships") or {}).get("appScreenshots") or {}).get("meta") or {}
        ).get("paging") or {}
        sets.append(
            {
                "display": entry["attributes"].get("screenshotDisplayType"),
                "count": paging.get("total"),
            }
        )
    return sets


def find_app(get: "Callable[[str], dict]") -> dict:
    """This app's record, or a hard stop.

    Takes the caller's `get` so that a script writing with a different key can
    find the same record without a second copy of this lookup —
    `scripts/testflight_distribute.py` does exactly that. Absence is a
    programming error, not a state to report: there is one App Store record and
    every script here is about it.
    """
    apps = get("/v1/apps?limit=200")["data"]
    app = next((a for a in apps if a["attributes"].get("bundleId") == BUNDLE_ID), None)
    if not app:
        raise SystemExit(f"no App Store Connect record for {BUNDLE_ID}")
    return app


def ci_products(get: "Callable[[str], dict]") -> list[dict]:
    """Every Xcode Cloud product on the team, each with the app it builds.

    `include=app` is what makes this worth having in one place. Without it the
    list carries links and no ids, so answering "whose product is this" costs a
    call per product — and on an orphaned product that call is an HTTP 500,
    which turns a question into a crash. With it, an orphan is simply a product
    whose `app` relationship has a type and no id, which is a value to test
    rather than an error to survive. See docs/guides/building.md.

    Every id is then re-fetched, because **being in this list is not evidence of
    existing.** The list is a cache and it has lied in both directions: it read
    `0` for ten minutes while two products still resolved, and it went on
    serving a deleted product for eighteen hours after a `DELETE` that answered
    `204`. A listed record that `404`s by id is a *ghost*, and it still carries
    its `app` relationship — so a ghost of this repo's own product looks exactly
    like a second claimant to `select_ci_product` below, which is a hard stop.
    That is not hypothetical: it killed `testflight_distribute.py` outright on
    2026-08-13 until the probe was added here.

    One call per product, and it belongs here rather than in each caller: the
    ghost lesson learned in one function and not another is the shape of the bug
    itself.
    """
    products = get("/v1/ciProducts?limit=200&include=app")["data"]
    return [
        {
            "id": product["id"],
            "name": product["attributes"]["name"],
            "created": product["attributes"].get("createdDate"),
            "appId": (product["relationships"]["app"].get("data") or {}).get("id"),
            "ghost": not _resolves(get, product["id"]),
        }
        for product in products
    ]


def _resolves(get: "Callable[[str], dict]", product_id: str) -> bool:
    """Does this product still exist, asked of the one endpoint that answers."""
    try:
        get(f"/v1/ciProducts/{product_id}")
        return True
    except SystemExit:
        return False


def select_ci_product(products: list[dict], app_id: str) -> str:
    """The one product that builds `app_id`, or a hard stop naming why not.

    **Matched on the app it builds, never on its name.** This is the safety
    property, not a style choice. The Create Workflow fault renames a product to the
    project that ran the wizard, so after a hijack the record called
    `NoSpoilersApp` was the sibling project's and the record called
    `FunMaxMusic` was this repo's. Name-matching would have picked precisely the
    wrong one and pointed this repo's tooling at another team member's project.
    The `app` relationship is the field the fault does not forge: it strips it
    to nothing rather than repointing it, so a seized product fails to match
    anything instead of matching the wrong thing.

    Two products claiming one app is not a tie to break. It means a record is
    mid-hijack, and choosing either could act on a sibling's product, so it
    stops.

    Ghosts are excluded before any of that. A deleted product keeps its `app`
    relationship in the listing, so its ghost claims this app as loudly as the
    live record does — and the stop above would then fire on a team that is
    perfectly healthy.
    """
    ours = [p for p in products if p["appId"] == app_id and not p["ghost"]]
    if len(ours) == 1:
        return ours[0]["id"]
    if not ours:
        seen = ", ".join(
            "{} -> app {}{}".format(
                p["name"],
                p["appId"] or "NONE (orphaned)",
                " [GHOST: listed but 404 by id]" if p["ghost"] else "",
            )
            for p in products
        )
        raise SystemExit(
            "no Xcode Cloud product builds this app.\n"
            f"{len(products)} product(s) on the team: {seen or 'none'}\n"
            "Recreate it with Integrate > Create Workflow in Xcode, then run "
            "scripts/ci_health.py. Read the Xcode Cloud bullets in "
            "docs/guides/building.md first — retrying that wizard while the list "
            "is empty seizes another "
            "project's product instead of creating one."
        )
    raise SystemExit(
        f"{len(ours)} Xcode Cloud products claim this app: "
        f"{', '.join(p['id'] for p in ours)}\n"
        "One of them is building something else. Do not guess which; see "
        "docs/guides/building.md."
    )


def find_ci_product(get: "Callable[[str], dict]", app_id: str) -> str:
    """This app's Xcode Cloud product id, discovered, or a hard stop.

    Discovered rather than recorded, because the id does not survive. This was
    a constant until 2026-08-12, on the reasoning that `GET /v1/ciProducts`
    could not be trusted — it was answering `total: 0` while products resolved
    by id. That was never an API quirk to route around: it was the fault in
    the Create Workflow fault, where an orphaned product makes the list
    unlistable. The
    orphans were deleted, and the constant they left behind pointed at a record
    that no longer existed, which took `testflight_distribute.py` down with it,
    dry run included. A recorded id survives exactly until the next deletion.

    Absence is a hard stop rather than `None`. Every caller here is asking
    about a build Xcode Cloud produced, so a missing product means the question
    is unanswerable, not that the answer is nothing.
    """
    return select_ci_product(ci_products(get), app_id)


def builds_path(app_id: str, platform: str) -> str:
    """Every build of this app on one platform.

    The platform filter is not a convenience. One record covers macOS and iOS
    under Universal Purchase, so without it this returns both interleaved by
    date and the newest upload is as likely to be a Mac build — measured on this
    app, 8 unfiltered against 4 filtered.
    """
    return f"/v1/builds?filter[app]={app_id}&filter[preReleaseVersion.platform]={platform}&limit=200"


def platform_builds(get: "Callable[[str], dict]", app_id: str, platform: str) -> list[dict]:
    """One platform's builds, cut down to the four fields anything here asks for."""
    return [
        {
            "id": build["id"],
            "version": build["attributes"]["version"],
            "expired": build["attributes"]["expired"],
            "uploaded": build["attributes"]["uploadedDate"],
        }
        for build in get(builds_path(app_id, platform))["data"]
    ]


def live_builds(builds: list[dict]) -> list[dict]:
    """The builds a tester could install, most recently uploaded first.

    By upload date, never by build number. Two upload paths feed this one app
    record and their number bands are kept apart deliberately — `release.sh`
    counts from 10000, Xcode Cloud uses its run number — so the larger number is
    routinely the *older* build. See docs/guides/building.md.

    Expired builds are dropped rather than ranked last. A TestFlight build stops
    launching 90 days after upload, so an expired one is not a worse answer to
    "what can they install", it is not an answer.
    """
    return sorted((b for b in builds if not b["expired"]), key=lambda b: b["uploaded"], reverse=True)


def newest_build(builds: list[dict]) -> dict | None:
    """The most recently uploaded installable build, or None if there is none."""
    live = live_builds(builds)
    return live[0] if live else None


def groups_holding(get: "Callable[[str], dict]", build_id: str) -> set[str]:
    """Which tester groups actually hold this build.

    `GET /v1/betaGroups/{id}/builds` answers an empty list for an internal group
    whether or not the build is in it, so it distinguishes nothing and looks
    like a working substitute for this. Going the other way round is forbidden
    outright: `GET /v1/builds/{id}/betaGroups` allows CREATE and DELETE only. It
    has to be an *include* on the build, which is what this is.
    """
    return {g["id"] for g in get(f"/v1/builds/{build_id}?include=betaGroups").get("included") or []}


def tester_groups(get: "Callable[[str], dict]", app_id: str) -> list[dict]:
    """The app's tester groups and how many testers each holds.

    **App-wide, not per-platform.** A group takes an iOS build and a Mac build
    alike, so this is fetched once for the whole section rather than inside
    `distribution` — which is where it lived while the report covered one
    platform, and where a second platform would have made it fetch and print the
    same groups twice.
    """
    groups = []
    for group in get(f"/v1/apps/{app_id}/betaGroups?limit=50")["data"]:
        # `meta.paging.total` rather than counting the page: an external group
        # may hold thousands of testers and the count is the only part used.
        paging = get(f"/v1/betaGroups/{group['id']}/betaTesters?limit=200")["meta"]["paging"]
        groups.append(
            {
                "name": group["attributes"]["name"],
                "internal": group["attributes"]["isInternalGroup"],
                "testers": paging["total"],
            }
        )
    return groups


def distribution(get: "Callable[[str], dict]", app_id: str, platform: str) -> dict:
    """Which build the testers can install on one platform, and how far behind.

    There is no cheap query for this and the expense is the point. Delivery is a
    command somebody runs, so "the newest build reaches nobody" is the ordinary
    state after every single push — warning about it would leave this report
    permanently red, which is the same as having no warning at all and takes the
    exit code down with it. The fact worth printing is the one nothing else
    shows: which build the testers *do* have.

    So walk the installable builds newest-first and stop at the first one any
    group holds. That is one request per undistributed build, which is the price
    of the group's own build list being useless — and it is per platform, so
    covering both doubles it. Ten each is still cheap.

    `uploaded` counts every build including the expired ones, and exists so that
    "no build has been uploaded" and "every build has expired" cannot be
    reported as each other. They arrive here as the same `newest: None`.
    """
    builds = platform_builds(get, app_id, platform)
    live = live_builds(builds)
    walked = live[:DISTRIBUTION_WALK]
    behind, held = None, None
    for index, build in enumerate(walked):
        if groups_holding(get, build["id"]):
            behind, held = index, build
            break

    return {
        "platform": platform,
        "uploaded": len(builds),
        "newest": live[0]["version"] if live else None,
        "installable": held["version"] if held else None,
        "behind": behind,
        "searched": len(walked) if held is None else behind + 1,
        # Distinguishes "nobody has been given anything in a fortnight" from
        # "nothing has ever been delivered", which read identically otherwise.
        "truncated": held is None and len(live) > DISTRIBUTION_WALK,
    }


def installable_phrase(entry: dict) -> str:
    """The one line this section exists to print, for one platform.

    "nothing" is an answer and is written as one. A dash or a blank here reads as
    missing data, and the state it would be hiding — every tester stuck without
    an installable build — is precisely what this is for.
    """
    newest, version, behind = (
        entry["newest"],
        entry["installable"],
        entry["behind"],
    )
    if version is None:
        if newest is None:
            # A platform with no builds and a platform whose builds have all
            # aged out both land here, and they are not the same thing to
            # anybody trying to fix it.
            return "nothing — every build has expired" if entry["uploaded"] else "nothing — no build exists"
        if entry["truncated"]:
            return f"nothing — none of the newest {entry['searched']} builds is in a group"
        return f"nothing — no build is in a group ({entry['searched']} checked)"
    if behind == 0:
        return f"build {version} — the newest"
    return f"build {version}, {behind} build{'' if behind == 1 else 's'} behind build {newest}"


def submission_items(get: "Callable[[str], dict]", submission_id: str) -> list[str]:
    """The state of each thing inside one review submission.

    A submission is a container, not a single object: a version, and optionally
    custom product pages, app events and experiments, each reviewed on its own.
    The submission's own `state` says the whole thing has unresolved issues —
    only the item states say which part Apple actually refused.

    Fetched per submission rather than read off `include=items` on the
    collection, where the inline list pages at ten and would silently drop the
    rest. A submission big enough to truncate is exactly the one whose item
    states are worth reading.
    """
    items = get(f"/v1/reviewSubmissions/{submission_id}/items?limit=50")["data"]
    return [item["attributes"]["state"] for item in items]


def item_states(states: list[str]) -> str:
    """How the item states read on one line.

    Tallied rather than listed because the API gives an item no name of its
    own — its id is an opaque blob — so three lines reading `REJECTED` would
    say nothing three times. What can be said is how many, and of what.
    """
    if not states:
        return "no items"
    if len(states) == 1:
        return states[0]
    return ", ".join(f"{states.count(state)} {state}" for state in dict.fromkeys(states))


def gather(client: Client) -> dict:
    """Everything the report needs, as plain data. No password ever enters it."""
    app = find_app(client.get)
    attributes = app["attributes"]
    report: dict = {
        "app": {
            "id": app["id"],
            "name": attributes.get("name"),
            "bundleId": attributes.get("bundleId"),
            "primaryLocale": attributes.get("primaryLocale"),
            "contentRights": attributes.get("contentRightsDeclaration"),
        },
        "categories": {"primary": None, "secondary": None},
        "ageRating": None,
        "versions": [],
        "submissions": [],
        "testflight": None,
    }

    info = client.get(
        f"/v1/apps/{app['id']}/appInfos?include=primaryCategory,secondaryCategory,appInfoLocalizations"
    )
    # More than one `appInfo` exists while a version is in flight — one live, one
    # being edited. The live one is what the store shows, so it is the one worth
    # reporting; a rejected edit is reported through its version instead.
    live = next(
        (i for i in info["data"] if i["attributes"].get("state") == "READY_FOR_DISTRIBUTION"),
        None,
    ) or (info["data"][0] if info["data"] else None)
    app_locales: dict[str, dict] = {}
    if live:
        included = {(i["type"], i["id"]): i for i in info.get("included") or []}
        relationships = live.get("relationships") or {}
        for key in ("primaryCategory", "secondaryCategory"):
            # A category's id is its name — "SPORTS", "GAMES" — so the link is
            # the whole answer.
            linked = (relationships.get(key) or {}).get("data")
            report["categories"][key.replace("Category", "")] = linked["id"] if linked else None
        report["ageRating"] = live["attributes"].get("appStoreAgeRating")
        for linked in (relationships.get("appInfoLocalizations") or {}).get("data") or []:
            entry = included.get(("appInfoLocalizations", linked["id"]))
            if entry:
                app_locales[entry["attributes"]["locale"]] = entry["attributes"]

    versions = client.get(
        f"/v1/apps/{app['id']}/appStoreVersions?limit=20"
        "&include=appStoreVersionLocalizations,build"
    )
    included = {(i["type"], i["id"]): i for i in versions.get("included") or []}
    seen_platforms: set[str] = set()
    for version in versions["data"]:
        platform = version["attributes"].get("platform")
        # The list arrives newest first, so the first version seen for a
        # platform is its current one; older ones are history and reporting them
        # would bury the two lines that matter under a changelog.
        if platform in seen_platforms:
            continue
        seen_platforms.add(platform)

        relationships = version.get("relationships") or {}
        build = (relationships.get("build") or {}).get("data")
        entry = {
            "id": version["id"],
            "platform": platform,
            "string": version["attributes"].get("versionString"),
            "state": version["attributes"].get("appStoreState"),
            "releaseType": version["attributes"].get("releaseType"),
            "created": version["attributes"].get("createdDate"),
            "build": (included.get(("builds", build["id"])) or {}).get("attributes", {}).get("version")
            if build
            else None,
            "listing": [],
            "review": None,
        }
        for linked in (relationships.get("appStoreVersionLocalizations") or {}).get("data") or []:
            localization = included.get(("appStoreVersionLocalizations", linked["id"]))
            if not localization:
                continue
            fields = dict(localization["attributes"])
            # Name, subtitle and privacy policy belong to the app rather than
            # the version and are edited on a different page. Merged here
            # because nobody thinks of them as separate when asking whether a
            # locale is finished.
            fields.update(
                {k: v for k, v in (app_locales.get(fields["locale"]) or {}).items() if k != "locale"}
            )
            fields["screenshots"] = screenshot_families(
                platform, _screenshot_sets(client, localization["id"])
            )
            entry["listing"].append(fields)

        # 200 with a null body, not a 404, when nobody has filled the page in.
        detail = client.get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")["data"]
        if detail:
            entry["review"] = {k: detail["attributes"].get(k) for k in REVIEW_FIELDS}
            entry["review"]["demoAccountPasswordSet"] = bool(
                _text(detail["attributes"].get("demoAccountPassword"))
            )
        report["versions"].append(entry)

    report["submissions"] = [
        {
            "platform": s["attributes"].get("platform"),
            "state": s["attributes"].get("state"),
            "submitted": (s["attributes"].get("submittedDate") or "")[:10] or None,
            "items": submission_items(client.get, s["id"]),
        }
        for s in client.get(f"/v1/apps/{app['id']}/reviewSubmissions?limit=20")["data"]
    ]
    report["testflight"] = {
        "groups": tester_groups(client.get, app["id"]),
        "platforms": [distribution(client.get, app["id"], p) for p in TESTFLIGHT_PLATFORMS],
    }
    return report


def attention(report: dict) -> list[str]:
    """What is waiting on a person, most urgent first.

    Only what this report can see. App Privacy and price/availability are absent
    because they are unreadable, not because they are done, and a rejection's
    reasons are absent because Apple does not put them in the API.
    """
    found: list[str] = []

    for version in report["versions"]:
        platform, name, state = version["platform"], version["string"], version["state"]
        if state not in WORKING:
            continue
        if state == "PENDING_DEVELOPER_RELEASE":
            found.append(f"{platform} {name} is approved and waiting for you to release it")
            continue
        if state in ("REJECTED", "METADATA_REJECTED", "INVALID_BINARY"):
            found.append(
                f"{platform} {name} is {state}: what App Review said is in Resolution Center, "
                "not in this API"
            )
        if not version["build"]:
            found.append(f"{platform} {name} has no build attached")

        for fields in version["listing"]:
            locale = fields["locale"]
            empty = [label for key, label in REQUIRED_TEXT if not _text(fields.get(key))]
            if not _text(fields.get("privacyPolicyUrl")):
                empty.append("privacy policy URL")
            # Every version of this app is an update — it has been on sale since
            # 1.0.13 — so a blank "What's New" is a blank release note, not an
            # inapplicable field.
            if not _text(fields.get("whatsNew")):
                empty.append("what's new")
            if empty:
                found.append(f"{platform} {name} {locale}: {', '.join(empty)} empty")
            bare = [n for n, count in (fields.get("screenshots") or {}).items() if count == 0]
            if bare:
                found.append(f"{platform} {name} {locale}: no {' or '.join(bare)} screenshots")

        review = version["review"]
        if review is None:
            found.append(f"{platform} {name} has no App Review contact details")
        else:
            missing = [label for key, label in CONTACT if not _text(review.get(key))]
            if missing:
                found.append(f"{platform} {name} App Review contact is missing {', '.join(missing)}")
            if review.get("demoAccountRequired") and not review.get("demoAccountPasswordSet"):
                found.append(
                    f"{platform} {name} says a demo account is required and has no password set"
                )

    for submission in report["submissions"]:
        if submission["state"] == "UNRESOLVED_ISSUES":
            found.append(
                f"the {submission['platform']} submission of {submission['submitted']} is still "
                "UNRESOLVED_ISSUES: answer it in Resolution Center or withdraw it"
            )

    # Testers being behind is not a problem — with delivery a manual command it
    # is the normal state, and saying so every time would make this section
    # noise. That is doubly true now the section covers two platforms: a naive
    # port would have printed the same false alarm twice per push. Only being
    # able to install *nothing* is a failure, and each of these is a different
    # way of arriving at it.
    testflight = report["testflight"]

    # Said once. The groups are app-wide, so "there is nobody to deliver to" is
    # one fact about the app rather than one per platform.
    if not testflight["groups"]:
        found.append("there is no TestFlight group, so no build of either platform can reach anybody")
    elif not any(group["testers"] for group in testflight["groups"]):
        found.append("every TestFlight group is empty, so handing a build over would reach nobody")

    for entry in testflight["platforms"]:
        platform = entry["platform"]
        if entry["newest"] is None:
            # Two states arrive here identically and mean opposite things: a
            # platform nothing has ever been built for, and one whose builds
            # have aged out. Reporting the first as the second would send
            # somebody looking for a build that never existed.
            if entry["uploaded"]:
                found.append(
                    f"every {platform} TestFlight build has expired — "
                    "they stop launching after 90 days"
                )
            else:
                found.append(
                    f"App Store Connect holds no {platform} build at all, though every Xcode "
                    "Cloud run archives one"
                )
        elif entry["installable"] is None and not entry["truncated"]:
            found.append(
                f"no {platform} build is in a tester group, so testers can install nothing: "
                f"scripts/testflight_distribute.py --platform {platform_flag(platform)} --apply "
                "hands over the newest"
            )
    # A truncated walk is deliberately *not* one of these. It means the search
    # ran out, not that the answer is nothing — and on 2026-08-17 that
    # distinction was real: the macOS build a group held sat one past the end of
    # a ten-build walk, so this line would have declared a platform undelivered
    # while its testers had something to install. Flagging it anyway would also
    # smuggle in the warning this section refuses to make, since "the last
    # delivery is further back than the walk" is being behind, measured in
    # DISTRIBUTION_WALK. The section prints the truncation; NEEDS YOU does not
    # claim what it did not establish.
    return found


def _row(label: str, value: object, note: str = "", indent: int = 2) -> str:
    shown = _text(value) or "—"
    shown = " ".join(shown.split())
    if len(shown) > 52:
        shown = shown[:49] + "..."
    # The label column is a fixed width whatever the indent, so rows at the same
    # level line up. `testers can install` is exactly 19 and sets it.
    return f"{' ' * indent}{label:<19} {shown}{f'   {note}' if note else ''}"


def render(report: dict) -> str:
    app = report["app"]
    lines = [
        f"App        {app['name']} ({app['id']})",
        f"           {app['bundleId']} — one record, both platforms",
        "",
        "APP INFORMATION",
        _row("primary category", report["categories"]["primary"]),
        _row("secondary", report["categories"]["secondary"], "optional"),
        _row("content rights", report["app"]["contentRights"]),
        _row("age rating", report["ageRating"]),
    ]

    for version in report["versions"]:
        state = version["state"]
        meaning = WORKING.get(state) or WAITING.get(state) or ("on sale" if state == "READY_FOR_SALE" else "")
        held = f"build {version['build']}" if version["build"] else "no build attached"
        lines.append("")
        lines.append(f"{version['platform']}  {version['string']}  {state}  ({meaning})  {held}")
        for fields in version["listing"]:
            lines.append(f"  listing {fields['locale']}")
            for key, label, note in (
                ("name", "name", ""),
                ("subtitle", "subtitle", "optional"),
                ("privacyPolicyUrl", "privacy policy", ""),
                ("description", "description", ""),
                ("keywords", "keywords", ""),
                ("supportUrl", "support URL", ""),
                ("promotionalText", "promotional text", "optional"),
                ("whatsNew", "what's new", ""),
            ):
                lines.append(_row(label, fields.get(key), note))
            for name, count in (fields.get("screenshots") or {}).items():
                shown = "?" if count is None else ("none" if count == 0 else str(count))
                lines.append(_row(f"{name} screenshots", shown))
        review = version["review"] or {}
        for key, label in CONTACT:
            lines.append(_row(f"contact {label}", review.get(key)))
        if version["review"]:
            demo = (
                f"{review.get('demoAccountName') or 'no account'}, "
                f"password {'set' if review.get('demoAccountPasswordSet') else 'NOT set'}"
                if review.get("demoAccountRequired")
                else "not required"
            )
        else:
            demo = None
        lines.append(_row("demo account", demo))
        lines.append(_row("review notes", review.get("notes"), "optional"))

    lines.append("")
    lines.append("SUBMISSIONS")
    if report["submissions"]:
        for submission in report["submissions"]:
            lines.append(
                f"  {submission['platform']:<8} {submission['state']:<20} "
                f"{submission['submitted'] or '—'}  {item_states(submission['items'])}"
            )
    else:
        lines.append("  none")

    testflight = report["testflight"]
    lines.append("")
    lines.append("TESTFLIGHT")
    # Above the platforms rather than inside one of them, because a group holds
    # builds of both and printing it twice would imply two sets of testers.
    if testflight["groups"]:
        for group in testflight["groups"]:
            count = group["testers"]
            lines.append(
                _row(
                    "tester group",
                    f"{group['name']} ({'internal' if group['internal'] else 'external'})",
                    f"{count} tester{'' if count == 1 else 's'}",
                )
            )
    else:
        lines.append(_row("tester group", "none"))
    for entry in testflight["platforms"]:
        lines.append(f"  {entry['platform']}")
        lines.append(_row("newest build", entry["newest"], indent=4))
        lines.append(_row("testers can install", installable_phrase(entry), indent=4))

    lines.append("")
    lines.append("NOT VISIBLE HERE")
    lines.append(_row("app privacy", "unknown", "no API endpoint exists; use the browser"))
    lines.append(_row("price, territories", "unknown", "App Manager key only"))
    lines.append(_row("rejection reasons", "unknown", "Resolution Center only"))

    found = attention(report)
    lines.append("")
    if found:
        lines.append("NEEDS YOU")
        for item in found:
            lines.append(f"  ! {item}")
    else:
        lines.append("Nothing this report can see is waiting on you.")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--json", action="store_true", help="emit the report as JSON")
    parser.parse_args([a for a in sys.argv[1:] if a != "--selftest"])

    report = gather(Client())
    if "--json" in sys.argv:
        print(json.dumps({**report, "needsYou": attention(report)}, indent=2))
    else:
        print(render(report))
    return 1 if attention(report) else 0


def _version(**overrides) -> dict:
    version = {
        "id": "v",
        "platform": "IOS",
        "string": "1.0.22",
        "state": "PREPARE_FOR_SUBMISSION",
        "releaseType": "AFTER_APPROVAL",
        "created": "2026-08-01T00:00:00Z",
        "build": "1022",
        "listing": [
            {
                "locale": "en-GB",
                "name": "No Spoilers - Grand Prix",
                "subtitle": None,
                "privacyPolicyUrl": "https://example.invalid/privacy",
                "description": "Race week without the result.",
                "keywords": "f1,grand prix",
                "supportUrl": "https://example.invalid/support",
                "promotionalText": None,
                "whatsNew": "Fixes.",
                "screenshots": {"iPhone": 3, "iPad": 2},
            }
        ],
        "review": {
            "contactFirstName": "Nick",
            "contactLastName": "Pomfret",
            "contactEmail": "n@example.invalid",
            "contactPhone": "+44 7000 000000",
            "demoAccountName": "demo@example.invalid",
            "demoAccountRequired": True,
            "notes": None,
            "demoAccountPasswordSet": True,
        },
    }
    version.update(overrides)
    return version


def _distribution(platform: str = "IOS", **overrides) -> dict:
    """The ordinary state of this repo: testers on a build, several pushes behind."""
    entry = {
        "platform": platform,
        "uploaded": 9,
        "newest": "10",
        "installable": "4",
        "behind": 6,
        "searched": 7,
        "truncated": False,
    }
    entry.update(overrides)
    return entry


def _testflight(*platforms: dict, groups: list | None = None) -> dict:
    """The TestFlight section: groups once, then a walk per platform."""
    return {
        "groups": [{"name": "Internal", "internal": True, "testers": 1}]
        if groups is None
        else groups,
        "platforms": list(platforms) or [_distribution(p) for p in TESTFLIGHT_PLATFORMS],
    }


def _fixture(**overrides) -> dict:
    report = {
        "app": {
            "id": "1",
            "name": "No Spoilers - Grand Prix",
            "bundleId": BUNDLE_ID,
            "primaryLocale": "en-GB",
            "contentRights": "DOES_NOT_USE_THIRD_PARTY_CONTENT",
        },
        "categories": {"primary": "SPORTS", "secondary": None},
        "ageRating": "FOUR_PLUS",
        "versions": [_version()],
        "submissions": [
            {
                "platform": "MAC_OS",
                "state": "COMPLETE",
                "submitted": "2026-04-25",
                "items": ["APPROVED"],
            }
        ],
        "testflight": _testflight(),
    }
    report.update(overrides)
    return report


def _selftest() -> int:
    """Offline. No key, no network — signing uses a throwaway key."""
    import tempfile

    failures: list[str] = []

    def expect(name: str, report: dict, fragment: str | None) -> None:
        found = attention(report)
        if fragment is None:
            if found:
                failures.append(f"{name}: expected nothing waiting, got {found}")
        elif not any(fragment in item for item in found):
            failures.append(f"{name}: nothing mentioning {fragment!r}, got {found}")

    # DER integers are signed, so both the leading-zero strip and the pad back to
    # 32 bytes have to happen. These are the two cases that break a token.
    raw = der_to_raw(bytes([0x30, 0x08, 0x02, 0x02, 0x00, 0xFF, 0x02, 0x02, 0x00, 0x01]))
    if len(raw) != 64:
        failures.append(f"der_to_raw length: {len(raw)}")
    if raw[:32] != b"\x00" * 31 + b"\xff" or raw[32:] != b"\x00" * 31 + b"\x01":
        failures.append("der_to_raw mangled r or s")
    for bad in (b"", b"\x02\x01\x00", bytes([0x30, 0x03, 0x05, 0x01, 0x00])):
        try:
            der_to_raw(bad)
            failures.append(f"der_to_raw accepted {bad!r}")
        except ValueError:
            pass
    if _b64(b"\xfb\xff") != "-_8":
        failures.append("base64url is not url-safe")

    with tempfile.TemporaryDirectory() as tmp:
        key = Path(tmp) / "t.p8"
        subprocess.run(
            ["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", str(key)],
            check=True,
            capture_output=True,
        )
        header, claims, signature = token("issuer", "KID", key, now=1_700_000_000).split(".")
        pad = lambda s: s + "=" * (-len(s) % 4)  # noqa: E731
        if json.loads(base64.urlsafe_b64decode(pad(header)))["kid"] != "KID":
            failures.append("kid missing from header")
        decoded = json.loads(base64.urlsafe_b64decode(pad(claims)))
        if decoded["aud"] != "appstoreconnect-v1" or decoded["exp"] - decoded["iat"] != TOKEN_LIFETIME:
            failures.append("token claims are wrong")
        if len(base64.urlsafe_b64decode(pad(signature))) != 64:
            failures.append("signature is not 64 bytes")

    expect("everything ready", _fixture(), None)

    # A shipping app spends most of its life with nothing in preparation. That is
    # the ordinary state, and treating it as a problem would make the report
    # permanently red and therefore worthless.
    expect("on sale, nothing in flight", _fixture(versions=[_version(state="READY_FOR_SALE")]), None)
    for state in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
        expect(f"{state} is Apple's turn", _fixture(versions=[_version(state=state)]), None)

    # A live version's fields are frozen and complete by definition; chasing
    # blanks in one would invent work nobody can do.
    frozen = _version(state="READY_FOR_SALE", listing=[{**_version()["listing"][0], "whatsNew": None}])
    expect("blank field on a live version", _fixture(versions=[frozen]), None)

    expect("rejected", _fixture(versions=[_version(state="REJECTED")]), "Resolution Center")
    expect(
        "approved and unreleased",
        _fixture(versions=[_version(state="PENDING_DEVELOPER_RELEASE")]),
        "waiting for you to release",
    )
    if len(attention(_fixture(versions=[_version(state="PENDING_DEVELOPER_RELEASE", build=None)]))) != 1:
        failures.append("an approved version needs no listing audit; that is one line, not five")

    expect("no build", _fixture(versions=[_version(build=None)]), "no build attached")
    for blank in (None, "", "   "):
        listing = [{**_version()["listing"][0], "description": blank}]
        expect(f"description {blank!r}", _fixture(versions=[_version(listing=listing)]), "description")
    listing = [{**_version()["listing"][0], "whatsNew": None}]
    expect("no release note", _fixture(versions=[_version(listing=listing)]), "what's new")
    listing = [{**_version()["listing"][0], "screenshots": {"iPhone": 3, "iPad": 0}}]
    expect("no iPad shots", _fixture(versions=[_version(listing=listing)]), "no iPad screenshots")

    expect("no review detail", _fixture(versions=[_version(review=None)]), "no App Review contact")
    expect(
        "no phone",
        _fixture(versions=[_version(review={**_version()["review"], "contactPhone": None})]),
        "missing phone",
    )
    expect(
        "demo account with no password",
        _fixture(versions=[_version(review={**_version()["review"], "demoAccountPasswordSet": False})]),
        "no password set",
    )
    expect(
        "unresolved submission",
        _fixture(
            submissions=[
                {
                    "platform": "IOS",
                    "state": "UNRESOLVED_ISSUES",
                    "submitted": "2026-05-15",
                    "items": ["REJECTED"],
                }
            ]
        ),
        "UNRESOLVED_ISSUES",
    )

    # The item states are the only part of a rejection the API will say, so the
    # two ways of losing them both have to be caught: reading none, and reading
    # several and printing one.
    if item_states([]) != "no items":
        failures.append(f"empty submission: {item_states([])!r}")
    if item_states(["REJECTED"]) != "REJECTED":
        failures.append(f"single item: {item_states(['REJECTED'])!r}")
    tallied = item_states(["APPROVED", "REJECTED", "APPROVED"])
    if tallied != "2 APPROVED, 1 REJECTED":
        failures.append(f"mixed items: {tallied!r}")

    # `?limit=50` on the relationship rather than `include=items` on the
    # collection: the inline list pages at ten, and a fetch that quietly
    # returned the first ten of a twelve-item submission would read as a
    # complete answer.
    asked: list[str] = []

    def _items(path: str) -> dict:
        asked.append(path)
        return {"data": [{"attributes": {"state": "APPROVED"}}, {"attributes": {"state": "REJECTED"}}]}

    if submission_items(_items, "sub-1") != ["APPROVED", "REJECTED"]:
        failures.append("submission_items dropped a state")
    if asked != ["/v1/reviewSubmissions/sub-1/items?limit=50"]:
        failures.append(f"submission_items asked for {asked}")

    # Picking the Xcode Cloud product, replayed against the real state of
    # 2026-08-12, when two projects' products were crossed. Every case
    # here is one this team has actually been in, and the cost of getting one
    # wrong is this repo's tooling driving another project's product.
    OURS, THEIRS = "6761343835", "6770023782"

    # The hijack, exactly as it stood: the record *named* NoSpoilersApp belonged
    # to the sibling, and the record named FunMaxMusic was ours. Anything that
    # reads the name picks the sibling's product here.
    def ci(id_, name, app, ghost=False):
        return {"id": id_, "name": name, "appId": app, "ghost": ghost}

    hijacked = [
        ci("EDF20772", "NoSpoilersApp", THEIRS),
        ci("1F3A0BBD", "FunMaxMusic", OURS),
    ]
    if select_ci_product(hijacked, OURS) != "1F3A0BBD":
        failures.append("select_ci_product followed the name instead of the app")

    # A sibling's product must never be selected, whatever it is called and
    # however alone it is in the list. Today's real state: one product, theirs.
    for lonely in ("FunMaxMusic", "NoSpoilersApp"):
        try:
            chosen = select_ci_product([ci("CADFB659", lonely, THEIRS)], OURS)
            failures.append(f"select_ci_product chose a sibling product named {lonely}: {chosen}")
        except SystemExit:
            pass

    # An orphan — the seized record, stripped of its app — must not be adopted
    # just because it is the only thing left.
    try:
        chosen = select_ci_product([ci("EDF20772", "NoSpoilersApp", None)], OURS)
        failures.append(f"select_ci_product adopted an orphan: {chosen}")
    except SystemExit:
        pass

    # Mid-hijack: two records claiming our app is not a tie to break.
    try:
        chosen = select_ci_product([ci("a", "x", OURS), ci("b", "y", OURS)], OURS)
        failures.append(f"select_ci_product guessed between two claimants: {chosen}")
    except SystemExit:
        pass

    # And the ordinary case still works, with a sibling sitting beside us.
    healthy = [
        ci("CADFB659", "FunMaxMusic", THEIRS),
        ci("NEW", "NoSpoilersApp", OURS),
    ]
    if select_ci_product(healthy, OURS) != "NEW":
        failures.append("select_ci_product missed the healthy product")

    # 2026-08-13, and the reason this exists: our own deleted product was still
    # being listed eighteen hours later, carrying our app id. It claims this app
    # exactly as loudly as the live record, so counting it turns a healthy team
    # into "2 products claim this app" and stops the tool dead. It did.
    with_ghost = [
        ci("F6A2F0EB", "NoSpoilersApp", OURS, ghost=True),
        ci("9C40B27D", "NoSpoilersApp", OURS),
    ]
    if select_ci_product(with_ghost, OURS) != "9C40B27D":
        failures.append("select_ci_product counted a ghost as a second claimant")

    # A ghost must not be selectable even when it is the only thing claiming us:
    # acting on a deleted product is not better than stopping.
    try:
        chosen = select_ci_product([ci("F6A2F0EB", "NoSpoilersApp", OURS, ghost=True)], OURS)
        failures.append(f"select_ci_product selected a ghost: {chosen}")
    except SystemExit:
        pass

    # Screenshot families are per platform: a macOS version has desktop shots and
    # no iPhone ones, and asking it for iPhone screenshots would report a gap
    # that cannot exist.
    mac = screenshot_families("MAC_OS", [{"display": "APP_DESKTOP", "count": 4}])
    if mac != {"desktop": 4}:
        failures.append(f"macOS families: {mac}")
    ios = screenshot_families(
        "IOS",
        [
            {"display": "APP_IPHONE_65", "count": 1},
            {"display": "APP_IPAD_PRO_3GEN_129", "count": 0},
            {"display": "APP_DESKTOP", "count": 9},
        ],
    )
    if ios != {"iPhone": 1, "iPad": 0}:
        failures.append(f"iOS families: {ios}")

    # An uncountable set is unknown, never zero. `meta.paging` appears only when
    # the request includes the screenshots, so this is one forgotten query
    # parameter away from inventing a blocker.
    unknown = screenshot_families("IOS", [{"display": "APP_IPHONE_69", "count": None}])
    if unknown != {"iPhone": None, "iPad": 0}:
        failures.append(f"uncountable set: {unknown}")
    listing = [{**_version()["listing"][0], "screenshots": {"iPhone": None, "iPad": 2}}]
    expect("uncountable screenshots", _fixture(versions=[_version(listing=listing)]), None)

    # The response carries a demo account password in the clear. It must not
    # survive into the report, and least of all into `--json`.
    if "demoAccountPassword" in REVIEW_FIELDS:
        failures.append("the demo account password is being copied into the report")
    if "ap19" in json.dumps(_fixture()):
        failures.append("a password reached a fixture")

    # Ordering the builds is where this goes wrong silently. `release.sh`
    # uploads from 10000 and Xcode Cloud uses its run number, so the newest
    # build has by far the smaller number; sorting numerically would report
    # testers as up to date on whatever was last shipped by hand.
    def _build(id_: str, version: str, uploaded: str, expired: bool = False) -> dict:
        return {"id": id_, "version": version, "uploaded": uploaded, "expired": expired}

    bands = [
        _build("manual", "10001", "2026-08-01T09:00:00-07:00"),
        _build("ci", "5", "2026-08-10T01:59:08-07:00"),
    ]
    if (newest := newest_build(bands)) is None or newest["id"] != "ci":
        failures.append(f"newest_build sorted by number, not date: {newest}")
    # And the other way round, so the case above cannot pass by accident.
    if (newest := newest_build(bands[::-1])) is None or newest["id"] != "ci":
        failures.append("newest_build depends on the order the API returned")
    if [b["id"] for b in live_builds(bands)] != ["ci", "manual"]:
        failures.append("live_builds is not newest-first")

    # An expired build is never the answer, however new: it will not launch, and
    # offering it would hide the older one that still would.
    expired_newest = [
        _build("a", "3", "2026-08-01T00:00:00-07:00"),
        _build("b", "4", "2026-08-10T00:00:00-07:00", expired=True),
    ]
    if (newest := newest_build(expired_newest)) is None or newest["id"] != "a":
        failures.append(f"newest_build chose an expired build: {newest}")
    if newest_build([]) is not None:
        failures.append("newest_build invented a build from nothing")
    if newest_build([_build("a", "1", "2026-01-01T00:00:00-07:00", expired=True)]) is not None:
        failures.append("newest_build returned an expired build as the only candidate")

    # One record holds both platforms, and the newest upload is as likely to be
    # either, so every build query is filtered.
    for platform in TESTFLIGHT_PLATFORMS:
        path = builds_path("123", platform)
        if f"filter[preReleaseVersion.platform]={platform}" not in path:
            failures.append(f"builds_path lost the platform filter for {platform}")
        if "filter[app]=123" not in path:
            failures.append("builds_path lost the app filter")

    # The report covers macOS because Xcode Cloud archives it. Losing that is
    # losing the whole point of this section: a stranded Mac build reads as no
    # Mac build, and every other signal reads as success.
    if "MAC_OS" not in TESTFLIGHT_PLATFORMS:
        failures.append("the report stopped covering macOS")
    if platform_flag("MAC_OS") != "macos" or platform_flag("IOS") != "ios":
        failures.append("the --platform flag named for a platform would not deliver to it")
    try:
        stray = platform_flag("TVOS")
        failures.append(f"platform_flag invented a flag for an uncovered platform: {stray}")
    except SystemExit:
        pass

    # The phrase is the whole point of the section, so its four shapes are
    # pinned. Singular and plural because "1 builds behind" is the kind of thing
    # that makes a report look unmaintained.
    if installable_phrase(_distribution(installable="10", behind=0)) != "build 10 — the newest":
        failures.append("a fully delivered build is not reported as the newest")
    if "1 build behind" not in installable_phrase(_distribution(installable="9", behind=1)):
        failures.append("one build behind is not singular")
    if "6 builds behind build 10" not in installable_phrase(_distribution()):
        failures.append("the behind-count does not name both builds")
    for name, entry in (
        (
            "no builds at all",
            _distribution(uploaded=0, newest=None, installable=None, behind=None, searched=0),
        ),
        ("walk truncated", _distribution(installable=None, behind=None, searched=10, truncated=True)),
        ("nothing delivered", _distribution(installable=None, behind=None, searched=3)),
    ):
        if not installable_phrase(entry).startswith("nothing"):
            failures.append(f"{name}: 'nothing' was not said plainly")

    # The distinction task 23 was filed for, at the level of the printed line:
    # a Mac build nobody handed over, against no Mac build at all. Both are
    # "testers can install nothing" and they need entirely different work.
    stranded = installable_phrase(_distribution("MAC_OS", installable=None, behind=None, searched=4))
    absent = installable_phrase(
        _distribution("MAC_OS", uploaded=0, newest=None, installable=None, behind=None, searched=0)
    )
    if stranded == absent:
        failures.append("a stranded build and a platform with no builds print identically")
    if "no build exists" not in absent:
        failures.append(f"a platform with no builds does not say so: {absent!r}")
    if "expired" not in installable_phrase(
        _distribution("MAC_OS", newest=None, installable=None, behind=None, searched=0)
    ):
        failures.append("an all-expired platform was reported as having no builds")

    # The trap this section was designed around: with delivery a manual command
    # the testers are behind after every push, and a warning that is always on
    # is the same as no warning. Being behind must stay silent — on both
    # platforms, since a naive port would have doubled the false alarm.
    expect("testers behind but installing", _fixture(), None)
    expect(
        "behind on both platforms",
        _fixture(testflight=_testflight(_distribution("IOS"), _distribution("MAC_OS"))),
        None,
    )
    expect(
        "nothing in any group",
        _fixture(
            testflight=_testflight(_distribution(installable=None, behind=None, searched=7))
        ),
        "can install nothing",
    )

    # A walk that ran out is not a platform with nothing delivered. Measured on
    # 2026-08-17: the macOS build a group held was the eleventh, one past a
    # ten-build walk, and claiming "testers can install nothing" there is a
    # false statement about a platform that was merely behind.
    ran_out = _fixture(
        testflight=_testflight(
            _distribution(
                "MAC_OS", installable=None, behind=None, searched=20, truncated=True
            )
        )
    )
    expect("walk truncated is not a failure", ran_out, None)
    if "none of the newest" not in installable_phrase(ran_out["testflight"]["platforms"][0]):
        failures.append("a truncated walk did not say the search ran out")

    # The whole point of the task: iOS delivered, Mac stranded. The report has
    # to name macOS, and it has to name the command that fixes macOS rather than
    # the one that fixes iOS.
    mac_stranded = _fixture(
        testflight=_testflight(
            _distribution("IOS"),
            _distribution("MAC_OS", installable=None, behind=None, searched=4),
        )
    )
    expect("mac stranded, ios fine", mac_stranded, "no MAC_OS build is in a tester group")
    if not any("--platform macos" in item for item in attention(mac_stranded)):
        failures.append("a stranded Mac build was answered with the iOS delivery command")
    if any("IOS build is in a tester group" in item for item in attention(mac_stranded)):
        failures.append("a healthy iOS platform was reported alongside the stranded Mac one")

    # And a Mac platform with nothing on it is a different sentence again.
    no_mac = _fixture(
        testflight=_testflight(
            _distribution("IOS"),
            _distribution("MAC_OS", uploaded=0, newest=None, installable=None, behind=None, searched=0),
        )
    )
    expect("no mac build at all", no_mac, "holds no MAC_OS build at all")
    if any("expired" in item for item in attention(no_mac)):
        failures.append("a platform with no builds was reported as one whose builds expired")

    # The groups are app-wide, so their two failures are said once however many
    # platforms are covered — twice would read as two separate audiences.
    empty_groups = _fixture(testflight=_testflight(groups=[]))
    expect("no groups exist", empty_groups, "no TestFlight group")
    if len([i for i in attention(empty_groups) if "TestFlight group" in i]) != 1:
        failures.append("the missing-group warning was printed once per platform")
    expect(
        "group with no testers",
        _fixture(
            testflight=_testflight(groups=[{"name": "Internal", "internal": True, "testers": 0}])
        ),
        "reach nobody",
    )
    # Everything expired says so, rather than blaming the delivery command for a
    # hand-over that would not help.
    gone = _fixture(
        testflight=_testflight(
            _distribution(newest=None, installable=None, behind=None, searched=0)
        )
    )
    expect("every build expired", gone, "expired")
    if any("can install nothing" in item for item in attention(gone)):
        failures.append("an all-expired app was reported as an undelivered one")

    # Groups are fetched by `tester_groups` and by nothing else. The walk asking
    # for them again is what would print one audience twice, and it is invisible
    # in the output until somebody counts the requests.
    asked: list[str] = []

    def _walk(path: str) -> dict:
        asked.append(path)
        if "/betaGroups" in path:
            return {"data": []}
        if path.startswith("/v1/builds?"):
            return {
                "data": [
                    {
                        "id": "b1",
                        "attributes": {
                            "version": "15",
                            "expired": False,
                            "uploadedDate": "2026-08-14T00:00:00-07:00",
                        },
                    }
                ]
            }
        return {"included": [{"id": "g1"}]}

    walked = distribution(_walk, "app-1", "MAC_OS")
    if any("betaGroups?limit" in path or "/betaTesters" in path for path in asked):
        failures.append(f"distribution fetched the tester groups itself: {asked}")
    if walked["platform"] != "MAC_OS" or walked["installable"] != "15":
        failures.append(f"distribution did not walk the platform it was given: {walked}")
    if not any("filter[preReleaseVersion.platform]=MAC_OS" in path for path in asked):
        failures.append("distribution asked for builds without the platform filter")

    rendered = render(_fixture())
    for fragment in (
        "APP INFORMATION",
        "IOS  1.0.22",
        "TESTFLIGHT",
        "6 builds behind build 10",
        "NOT VISIBLE HERE",
        "Resolution Center only",
        "COMPLETE             2026-04-25  APPROVED",
    ):
        if fragment not in rendered:
            failures.append(f"render dropped {fragment!r}")

    # Both platforms appear, and the tester group appears once above them.
    for platform in TESTFLIGHT_PLATFORMS:
        if f"\n  {platform}\n" not in rendered:
            failures.append(f"render dropped the {platform} block")
    if rendered.count("tester group") != 1:
        failures.append("the tester group was printed once per platform")
    if rendered.count("testers can install") != len(TESTFLIGHT_PLATFORMS):
        failures.append("a platform was rendered without its installable line")
    if "!" in rendered:
        failures.append("a ready fixture should render nothing under NEEDS YOU")
    if "password set" not in rendered or "ap19" in rendered:
        failures.append("the demo account should render as set, never as a value")

    for failure in failures:
        print(f"  FAIL {failure}", file=sys.stderr)
    print(f"appstore_status selftest: 84 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    sys.exit(main())
